#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is required but not installed."
        exit 1
    fi
    
    # Check if helm is available
    if ! command -v helm &> /dev/null; then
        print_error "helm is required but not installed."
        exit 1
    fi
    
    # Check if DD_API_KEY is set
    if [ -z "$DD_API_KEY" ]; then
        print_error "DD_API_KEY environment variable is required."
        echo "Please set it with: export DD_API_KEY=<your-datadog-api-key>"
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot access Kubernetes cluster. Please check your kubectl configuration."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Deploy Scenario 3: DDOT Collector
deploy_scenario3() {
    print_status "Deploying Scenario 3: Datadog Distribution of OpenTelemetry (DDOT) Collector..."
    
    # Capture Git information for Datadog source code integration
    print_status "Capturing Git information for version tagging..."
    source scripts/capture-git-info.sh export
    
    # Create namespace for Datadog
    print_status "Creating datadog namespace..."
    kubectl create namespace datadog --dry-run=client -o yaml | kubectl apply -f -
    
    # Create Datadog secret
    print_status "Creating Datadog API secret..."
    kubectl delete secret datadog-secret -n datadog --ignore-not-found=true
    kubectl create secret generic datadog-secret \
        --from-literal=api-key="$DD_API_KEY" \
        --from-literal=app-key="${DD_APP_KEY:-}" \
        -n datadog
    
    # Apply Datadog Agent with DDOT Collector
    print_status "Deploying Datadog Agent with DDOT Collector..."
    kubectl apply -f operators/datadog/scenario3/datadog-agent-ddot.yaml
    
    # Wait for Datadog Agent to be ready
    print_status "Waiting for Datadog Agent to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=datadog-agent -n datadog --timeout=300s
    
    print_success "Datadog Agent with DDOT Collector deployed successfully"
    
    # Deploy applications
    print_status "Deploying applications..."
    
    # Build Docker images with Git information
    print_status "Building Docker images with Git version tagging..."
    
    # Display Git information
    print_status "Git Information:"
    echo "  Commit SHA: $DD_GIT_COMMIT_SHA"
    echo "  Repository: $DD_GIT_REPOSITORY_URL"
    
    # API Service
    docker build applications/api/ \
        -t otel-demo/api:scenario3 \
        --build-arg DD_GIT_REPOSITORY_URL="$DD_GIT_REPOSITORY_URL" \
        --build-arg DD_GIT_COMMIT_SHA="$DD_GIT_COMMIT_SHA"
    
    # Database Service  
    docker build applications/database/ \
        -t otel-demo/database:scenario3 \
        --build-arg DD_GIT_REPOSITORY_URL="$DD_GIT_REPOSITORY_URL" \
        --build-arg DD_GIT_COMMIT_SHA="$DD_GIT_COMMIT_SHA"
    
    # Frontend Service
    docker build applications/frontend/ \
        -t otel-demo/frontend:scenario3 \
        --build-arg DD_GIT_REPOSITORY_URL="$DD_GIT_REPOSITORY_URL" \
        --build-arg DD_GIT_COMMIT_SHA="$DD_GIT_COMMIT_SHA"
    
    # Deploy applications via Helm with Scenario 3 configuration
    print_status "Installing applications via Helm with Git version tagging..."
    helm upgrade --install otel-demo-scenario3 helm/otel-demo \
        --namespace otel-demo-scenario3 \
        --create-namespace \
        --set global.scenario="scenario3" \
        --set global.otelEndpoint="http://datadog-agent-ddot.datadog.svc.cluster.local:4317" \
        --set global.ddotCollectorEnabled=true \
        --set global.gitCommitSha="$DD_GIT_COMMIT_SHA" \
        --set global.gitRepositoryUrl="$DD_GIT_REPOSITORY_URL" \
        --set api.image.tag="scenario3" \
        --set database.image.tag="scenario3" \
        --set frontend.image.tag="scenario3" \
        --wait
    
    print_success "Applications deployed successfully"
}

# Show deployment information
show_deployment_info() {
    print_status "Deployment Information for Scenario 3:"
    echo
    echo "Architecture: Microservices → OTLP → Datadog Agent (DDOT Collector) → Datadog Platform"
    echo
    echo "Key Features of DDOT Collector:"
    echo "- Curated OpenTelemetry components optimized for Datadog"
    echo "- Full Datadog Agent capabilities integrated"
    echo "- Enhanced Kubernetes attribute processing"
    echo "- Unified service tagging out-of-the-box"
    echo "- Fleet automation support"
    echo
    
    print_status "Checking pod status..."
    echo
    echo "Datadog Agent pods:"
    kubectl get pods -n datadog -l app.kubernetes.io/name=datadog-agent
    echo
    echo "Application pods:"
    kubectl get pods -n otel-demo-scenario3
    echo
    
    print_status "Service endpoints:"
    echo
    echo "To access the frontend application:"
    echo "kubectl port-forward -n otel-demo-scenario3 svc/frontend-service 3000:80"
    echo "Then open: http://localhost:3000"
    echo
    
    echo "To access the API directly:"
    echo "kubectl port-forward -n otel-demo-scenario3 svc/api-service 5001:80"
    echo "Then test: curl http://localhost:5001/health"
    echo
    
    print_status "Datadog Agent with DDOT Collector status:"
    kubectl get datadogagent -n datadog datadog-agent-ddot
    echo
    
    print_status "To view DDOT Collector configuration:"
    echo "kubectl get configmap ddot-collector-config -n datadog -o yaml"
    echo
    
    print_success "Scenario 3 deployment completed!"
    echo
    print_warning "Note: It may take a few minutes for telemetry data to appear in Datadog."
    echo "Check your Datadog dashboard for traces, metrics, and logs from the microservices."
}

# Cleanup function
cleanup_scenario3() {
    print_status "Cleaning up Scenario 3 deployment..."
    
    # Remove Helm deployment
    helm uninstall otel-demo-scenario3 -n otel-demo-scenario3 2>/dev/null || true
    kubectl delete namespace otel-demo-scenario3 --ignore-not-found=true
    
    # Remove Datadog Agent
    kubectl delete -f operators/datadog/scenario3/datadog-agent-ddot.yaml --ignore-not-found=true
    kubectl delete secret datadog-secret -n datadog --ignore-not-found=true
    
    print_success "Scenario 3 cleanup completed"
}

# Main execution
main() {
    case "${1:-deploy}" in
        "deploy")
            check_prerequisites
            deploy_scenario3
            show_deployment_info
            ;;
        "cleanup")
            cleanup_scenario3
            ;;
        "info")
            show_deployment_info
            ;;
        *)
            echo "Usage: $0 [deploy|cleanup|info]"
            echo "  deploy  - Deploy Scenario 3 (default)"
            echo "  cleanup - Remove Scenario 3 deployment"
            echo "  info    - Show deployment information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
