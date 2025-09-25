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
    
    # Check if Datadog Operator is installed
    if ! kubectl get deployment datadog-operator -n datadog &> /dev/null; then
        print_error "Datadog Operator not found. Please run './scripts/operators/install-operators.sh' first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Deploy Scenario 1: Direct to Datadog Agent
deploy_scenario1() {
    print_status "Deploying Scenario 1: Direct to Datadog Agent..."
    
    # Capture Git information for Datadog source code integration
    print_status "Capturing Git information for version tagging..."
    source scripts/capture-git-info.sh export
    
    # Apply Datadog Agent for Scenario 1
    print_status "Deploying Datadog Agent for direct OTLP ingestion..."
    kubectl apply -f operators/datadog/scenario1/datadog-agent.yaml
    
    # Wait for Datadog Agent to be ready
    print_status "Waiting for Datadog Agent to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=datadog-agent -n datadog --timeout=300s
    
    print_success "Datadog Agent deployed successfully"
    
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
        -t otel-demo/api:scenario1 \
        --build-arg DD_GIT_REPOSITORY_URL="$DD_GIT_REPOSITORY_URL" \
        --build-arg DD_GIT_COMMIT_SHA="$DD_GIT_COMMIT_SHA"
    
    # Database Service  
    docker build applications/database/ \
        -t otel-demo/database:scenario1 \
        --build-arg DD_GIT_REPOSITORY_URL="$DD_GIT_REPOSITORY_URL" \
        --build-arg DD_GIT_COMMIT_SHA="$DD_GIT_COMMIT_SHA"
    
    # Frontend Service
    docker build applications/frontend/ \
        -t otel-demo/frontend:scenario1 \
        --build-arg DD_GIT_REPOSITORY_URL="$DD_GIT_REPOSITORY_URL" \
        --build-arg DD_GIT_COMMIT_SHA="$DD_GIT_COMMIT_SHA"
    
    # Deploy applications via Helm with Scenario 1 configuration
    print_status "Installing applications via Helm..."
    helm upgrade --install otel-demo-scenario1 helm/otel-demo \
        --namespace otel-demo-scenario1 \
        --create-namespace \
        --set global.scenario="scenario1" \
        --set global.otelEndpoint="http://datadog-agent.datadog.svc.cluster.local:4317" \
        --set global.gitCommitSha="$DD_GIT_COMMIT_SHA" \
        --set global.gitRepositoryUrl="$DD_GIT_REPOSITORY_URL" \
        --set api.image.tag="scenario1" \
        --set database.image.tag="scenario1" \
        --set frontend.image.tag="scenario1" \
        --wait
    
    print_success "Applications deployed successfully"
}

# Show deployment information
show_deployment_info() {
    print_status "Deployment Information for Scenario 1:"
    echo
    echo "Architecture: Microservices → OTLP → Datadog Agent → Datadog Platform"
    echo
    echo "This scenario demonstrates:"
    echo "- Direct OTLP ingestion by Datadog Agent"
    echo "- Native Datadog APM processing"
    echo "- Full Datadog feature integration"
    echo "- Simplified telemetry pipeline"
    echo
    
    print_status "Checking pod status..."
    echo
    echo "Datadog Agent pods:"
    kubectl get pods -n datadog -l app.kubernetes.io/name=datadog-agent
    echo
    echo "Application pods:"
    kubectl get pods -n otel-demo-scenario1
    echo
    
    print_status "Service endpoints:"
    echo
    echo "To access the frontend application:"
    echo "kubectl port-forward -n otel-demo-scenario1 svc/frontend-service 3000:80"
    echo "Then open: http://localhost:3000"
    echo
    
    echo "To access the API directly:"
    echo "kubectl port-forward -n otel-demo-scenario1 svc/api-service 5001:80"
    echo "Then test: curl http://localhost:5001/health"
    echo
    
    print_status "Datadog Agent status:"
    kubectl get datadogagent -n datadog datadog-agent
    echo
    
    print_success "Scenario 1 deployment completed!"
    echo
    print_warning "Note: It may take a few minutes for telemetry data to appear in Datadog."
    echo "Check your Datadog dashboard for traces, metrics, and logs from the microservices."
}

# Cleanup function
cleanup_scenario1() {
    print_status "Cleaning up Scenario 1 deployment..."
    
    # Remove Helm deployment
    helm uninstall otel-demo-scenario1 -n otel-demo-scenario1 2>/dev/null || true
    kubectl delete namespace otel-demo-scenario1 --ignore-not-found=true
    
    # Remove Datadog Agent
    kubectl delete -f operators/datadog/scenario1/datadog-agent.yaml --ignore-not-found=true
    
    print_success "Scenario 1 cleanup completed"
}

# Main execution
main() {
    case "${1:-deploy}" in
        "deploy")
            check_prerequisites
            deploy_scenario1
            show_deployment_info
            ;;
        "cleanup")
            cleanup_scenario1
            ;;
        "info")
            show_deployment_info
            ;;
        *)
            echo "Usage: $0 [deploy|cleanup|info]"
            echo "  deploy  - Deploy Scenario 1 (default)"
            echo "  cleanup - Remove Scenario 1 deployment"
            echo "  info    - Show deployment information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
