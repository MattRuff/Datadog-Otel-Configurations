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
    
    # Check if OpenTelemetry Operator is installed
    if ! kubectl get deployment opentelemetry-operator-controller-manager -n opentelemetry-operator-system &> /dev/null; then
        print_error "OpenTelemetry Operator not found. Please run './scripts/operators/install-operators.sh' first."
        exit 1
    fi
    
    # Check if Datadog Operator is installed
    if ! kubectl get deployment datadog-operator -n datadog &> /dev/null; then
        print_error "Datadog Operator not found. Please run './scripts/operators/install-operators.sh' first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Deploy Scenario 2: Via OpenTelemetry Collector
deploy_scenario2() {
    print_status "Deploying Scenario 2: Via OpenTelemetry Collector..."
    
    # Capture Git information for Datadog source code integration
    print_status "Capturing Git information for version tagging..."
    source scripts/capture-git-info.sh export
    
    # Deploy Datadog Agent for infrastructure monitoring (minimal configuration)
    print_status "Deploying Datadog Agent for infrastructure monitoring..."
    kubectl apply -f operators/datadog/scenario2/datadog-agent.yaml
    
    # Deploy OpenTelemetry Collector
    print_status "Deploying OpenTelemetry Collector..."
    kubectl apply -f operators/opentelemetry/scenario2/otel-collector.yaml
    
    # Wait for deployments to be ready
    print_status "Waiting for Datadog Agent to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=datadog-agent -n datadog --timeout=300s
    
    print_status "Waiting for OpenTelemetry Collector to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=otel-collector -n opentelemetry --timeout=300s
    
    print_success "Datadog Agent and OpenTelemetry Collector deployed successfully"
    
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
        -t otel-demo/api:scenario2 \
        --build-arg DD_GIT_REPOSITORY_URL="$DD_GIT_REPOSITORY_URL" \
        --build-arg DD_GIT_COMMIT_SHA="$DD_GIT_COMMIT_SHA"
    
    # Database Service  
    docker build applications/database/ \
        -t otel-demo/database:scenario2 \
        --build-arg DD_GIT_REPOSITORY_URL="$DD_GIT_REPOSITORY_URL" \
        --build-arg DD_GIT_COMMIT_SHA="$DD_GIT_COMMIT_SHA"
    
    # Frontend Service
    docker build applications/frontend/ \
        -t otel-demo/frontend:scenario2 \
        --build-arg DD_GIT_REPOSITORY_URL="$DD_GIT_REPOSITORY_URL" \
        --build-arg DD_GIT_COMMIT_SHA="$DD_GIT_COMMIT_SHA"
    
    # Deploy applications via Helm with Scenario 2 configuration
    print_status "Installing applications via Helm..."
    helm upgrade --install otel-demo-scenario2 helm/otel-demo \
        --namespace otel-demo-scenario2 \
        --create-namespace \
        --set global.scenario="scenario2" \
        --set global.otelEndpoint="http://otel-collector.opentelemetry.svc.cluster.local:4317" \
        --set global.gitCommitSha="$DD_GIT_COMMIT_SHA" \
        --set global.gitRepositoryUrl="$DD_GIT_REPOSITORY_URL" \
        --set api.image.tag="scenario2" \
        --set database.image.tag="scenario2" \
        --set frontend.image.tag="scenario2" \
        --wait
    
    print_success "Applications deployed successfully"
}

# Show deployment information
show_deployment_info() {
    print_status "Deployment Information for Scenario 2:"
    echo
    echo "Architecture: Microservices → OTLP → OpenTelemetry Collector → Datadog Exporter → Datadog Platform"
    echo
    echo "This scenario demonstrates:"
    echo "- Vendor-neutral OpenTelemetry Collector"
    echo "- Flexible telemetry processing pipeline"
    echo "- Datadog exporter for final delivery"
    echo "- Full OpenTelemetry ecosystem compatibility"
    echo
    
    print_status "Checking pod status..."
    echo
    echo "Datadog Agent pods:"
    kubectl get pods -n datadog -l app.kubernetes.io/name=datadog-agent
    echo
    echo "OpenTelemetry Collector pods:"
    kubectl get pods -n opentelemetry -l app.kubernetes.io/name=otel-collector
    echo
    echo "Application pods:"
    kubectl get pods -n otel-demo-scenario2
    echo
    
    print_status "Service endpoints:"
    echo
    echo "To access the frontend application:"
    echo "kubectl port-forward -n otel-demo-scenario2 svc/frontend-service 3000:80"
    echo "Then open: http://localhost:3000"
    echo
    
    echo "To access the API directly:"
    echo "kubectl port-forward -n otel-demo-scenario2 svc/api-service 5001:80"
    echo "Then test: curl http://localhost:5001/health"
    echo
    
    echo "To access OpenTelemetry Collector metrics:"
    echo "kubectl port-forward -n opentelemetry svc/otel-collector 8888:8888"
    echo "Then check: curl http://localhost:8888/metrics"
    echo
    
    print_status "OpenTelemetry Collector status:"
    kubectl get opentelemetrycollector -n opentelemetry otel-collector
    echo
    
    print_status "Datadog Agent status:"
    kubectl get datadogagent -n datadog datadog-agent
    echo
    
    print_success "Scenario 2 deployment completed!"
    echo
    print_warning "Note: It may take a few minutes for telemetry data to appear in Datadog."
    echo "Check your Datadog dashboard for traces, metrics, and logs from the microservices."
}

# Cleanup function
cleanup_scenario2() {
    print_status "Cleaning up Scenario 2 deployment..."
    
    # Remove Helm deployment
    helm uninstall otel-demo-scenario2 -n otel-demo-scenario2 2>/dev/null || true
    kubectl delete namespace otel-demo-scenario2 --ignore-not-found=true
    
    # Remove OpenTelemetry Collector
    kubectl delete -f operators/opentelemetry/scenario2/otel-collector.yaml --ignore-not-found=true
    
    # Remove Datadog Agent
    kubectl delete -f operators/datadog/scenario2/datadog-agent.yaml --ignore-not-found=true
    
    print_success "Scenario 2 cleanup completed"
}

# Main execution
main() {
    case "${1:-deploy}" in
        "deploy")
            check_prerequisites
            deploy_scenario2
            show_deployment_info
            ;;
        "cleanup")
            cleanup_scenario2
            ;;
        "info")
            show_deployment_info
            ;;
        *)
            echo "Usage: $0 [deploy|cleanup|info]"
            echo "  deploy  - Deploy Scenario 2 (default)"
            echo "  cleanup - Remove Scenario 2 deployment"
            echo "  info    - Show deployment information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
