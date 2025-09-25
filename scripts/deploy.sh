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

# Show usage
show_usage() {
    echo "Usage: $0 <scenario> [action]"
    echo ""
    echo "Scenarios:"
    echo "  scenario1  - Direct to Datadog Agent"
    echo "  scenario2  - Via OpenTelemetry Collector"
    echo "  scenario3  - DDOT Collector (Datadog's OTel distribution)"
    echo ""
    echo "Actions:"
    echo "  deploy     - Deploy the scenario (default)"
    echo "  cleanup    - Remove the scenario deployment"
    echo "  info       - Show deployment information"
    echo ""
    echo "Examples:"
    echo "  $0 scenario1           # Deploy scenario 1"
    echo "  $0 scenario2 deploy    # Deploy scenario 2"
    echo "  $0 scenario3 cleanup   # Remove scenario 3"
    echo "  $0 scenario1 info      # Show scenario 1 info"
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

# Install operators if needed
ensure_operators() {
    print_status "Ensuring operators are installed..."
    
    # Check if Datadog Operator is installed
    if ! kubectl get deployment datadog-operator -n datadog &> /dev/null; then
        print_status "Installing Datadog Agent Operator..."
        
        # Add Datadog Helm repository
        helm repo add datadog https://helm.datadoghq.com
        helm repo update
        
        # Create namespace for Datadog
        kubectl create namespace datadog --dry-run=client -o yaml | kubectl apply -f -
        
        # Install Datadog Operator
        helm upgrade --install datadog-operator datadog/datadog-operator \
            --namespace datadog \
            --wait \
            --timeout=5m
    fi
    
    # Check if OpenTelemetry Operator is installed (only for scenario2)
    if [ "$1" = "scenario2" ]; then
        if ! kubectl get deployment opentelemetry-operator-controller-manager -n opentelemetry-operator-system &> /dev/null; then
            print_status "Installing OpenTelemetry Operator..."
            
            # Create namespace for OpenTelemetry
            kubectl create namespace opentelemetry --dry-run=client -o yaml | kubectl apply -f -
            
            # Install cert-manager if not already installed
            if ! kubectl get namespace cert-manager &> /dev/null; then
                print_status "Installing cert-manager (required for OpenTelemetry Operator)..."
                kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
                kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
            fi
            
            # Install OpenTelemetry Operator
            kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
            
            # Wait for operator to be ready
            kubectl wait --for=condition=available deployment/opentelemetry-operator-controller-manager \
                -n opentelemetry-operator-system \
                --timeout=300s
        fi
    fi
    
    print_success "Operators are ready"
}

# Create Datadog secret
create_datadog_secret() {
    print_status "Creating Datadog API secret..."
    
    kubectl delete secret datadog-secret -n datadog --ignore-not-found=true
    kubectl create secret generic datadog-secret \
        --from-literal=api-key="$DD_API_KEY" \
        --from-literal=app-key="${DD_APP_KEY:-}" \
        -n datadog
    
    # Also create in opentelemetry namespace for OTel Collector (scenario2)
    if kubectl get namespace opentelemetry &> /dev/null; then
        kubectl delete secret datadog-secret -n opentelemetry --ignore-not-found=true
        kubectl create secret generic datadog-secret \
            --from-literal=api-key="$DD_API_KEY" \
            --from-literal=app-key="${DD_APP_KEY:-}" \
            -n opentelemetry
    fi
    
    print_success "Datadog secrets created successfully"
}

# Build Docker images with Git information (single image for all scenarios)
build_images() {
    print_status "Building Docker images with Git version tagging..."
    
    # Capture Git information for Datadog source code integration
    source scripts/capture-git-info.sh export
    
    # Display Git information
    print_status "Git Information:"
    echo "  Commit SHA: $DD_GIT_COMMIT_SHA"
    echo "  Repository: $DD_GIT_REPOSITORY_URL"
    
    # Build all three services with a single tag (no scenario-specific images)
    for service in api database frontend; do
        print_status "Building $service image..."
        docker build applications/$service/ \
            -t otel-demo/$service:latest \
            --build-arg DD_GIT_REPOSITORY_URL="$DD_GIT_REPOSITORY_URL" \
            --build-arg DD_GIT_COMMIT_SHA="$DD_GIT_COMMIT_SHA"
    done
    
    print_success "Docker images built successfully"
}

# Deploy scenario
deploy_scenario() {
    local scenario=$1
    
    print_status "Deploying $scenario..."
    
    check_prerequisites
    ensure_operators "$scenario"
    create_datadog_secret
    build_images
    
    # Capture Git information
    source scripts/capture-git-info.sh export
    
    # Deploy via Helm using scenario-specific values (single image for all scenarios)
    print_status "Installing $scenario via Helm..."
    helm upgrade --install otel-demo-$scenario helm/otel-demo \
        --namespace otel-demo-$scenario \
        --create-namespace \
        --values helm/otel-demo/values-$scenario.yaml \
        --set global.gitCommitSha="$DD_GIT_COMMIT_SHA" \
        --set global.gitRepositoryUrl="$DD_GIT_REPOSITORY_URL" \
        --set api.image.tag="latest" \
        --set database.image.tag="latest" \
        --set frontend.image.tag="latest" \
        --wait \
        --timeout=10m
    
    print_success "$scenario deployed successfully"
    show_deployment_info "$scenario"
}

# Show deployment information
show_deployment_info() {
    local scenario=$1
    
    print_status "Deployment Information for $scenario:"
    echo
    
    case $scenario in
        "scenario1")
            echo "Architecture: Microservices → OTLP → Datadog Agent → Datadog Platform"
            echo "Service Names: datadog-frontend-service, datadog-api-service, datadog-database-service"
            ;;
        "scenario2")
            echo "Architecture: Microservices → OTLP → OpenTelemetry Collector → Datadog Platform"
            echo "Service Names: otel-frontend-service, otel-api-service, otel-database-service"
            ;;
        "scenario3")
            echo "Architecture: Microservices → OTLP → Datadog Agent (DDOT Collector) → Datadog Platform"
            echo "Service Names: ddot-frontend-service, ddot-api-service, ddot-database-service"
            ;;
    esac
    
    echo
    print_status "Checking pod status..."
    echo
    
    # Check Datadog Agent pods
    if kubectl get namespace datadog &> /dev/null; then
        echo "Datadog Agent pods:"
        kubectl get pods -n datadog -l app.kubernetes.io/name=datadog-agent 2>/dev/null || echo "No Datadog Agent pods found"
        echo
    fi
    
    # Check OpenTelemetry Collector pods (scenario2)
    if [ "$scenario" = "scenario2" ] && kubectl get namespace opentelemetry &> /dev/null; then
        echo "OpenTelemetry Collector pods:"
        kubectl get pods -n opentelemetry -l app.kubernetes.io/name=otel-collector 2>/dev/null || echo "No OpenTelemetry Collector pods found"
        echo
    fi
    
    # Check application pods
    echo "Application pods:"
    kubectl get pods -n otel-demo-$scenario 2>/dev/null || echo "No application pods found"
    echo
    
    print_status "Service endpoints:"
    echo
    echo "To access the frontend application:"
    echo "kubectl port-forward -n otel-demo-$scenario svc/frontend-service 3000:80"
    echo "Then open: http://localhost:3000"
    echo
    
    echo "To access the API directly:"
    echo "kubectl port-forward -n otel-demo-$scenario svc/api-service 5001:80"
    echo "Then test: curl http://localhost:5001/health"
    echo
    
    if [ "$scenario" = "scenario2" ]; then
        echo "To access OpenTelemetry Collector metrics:"
        echo "kubectl port-forward -n opentelemetry svc/otel-collector 8888:8888"
        echo "Then check: curl http://localhost:8888/metrics"
        echo
    fi
    
    print_success "$scenario deployment information displayed"
    echo
    print_warning "Note: It may take a few minutes for telemetry data to appear in Datadog."
    echo "Check your Datadog dashboard for traces, metrics, and logs from the microservices."
}

# Cleanup scenario
cleanup_scenario() {
    local scenario=$1
    
    print_status "Cleaning up $scenario deployment..."
    
    # Remove Helm deployment
    helm uninstall otel-demo-$scenario -n otel-demo-$scenario 2>/dev/null || true
    kubectl delete namespace otel-demo-$scenario --ignore-not-found=true
    
    print_success "$scenario cleanup completed"
}

# Main execution
main() {
    local scenario=${1:-}
    local action=${2:-deploy}
    
    # Validate arguments
    if [ -z "$scenario" ]; then
        print_error "Scenario is required"
        show_usage
        exit 1
    fi
    
    if [[ ! "$scenario" =~ ^scenario[123]$ ]]; then
        print_error "Invalid scenario: $scenario"
        show_usage
        exit 1
    fi
    
    if [[ ! "$action" =~ ^(deploy|cleanup|info)$ ]]; then
        print_error "Invalid action: $action"
        show_usage
        exit 1
    fi
    
    case "$action" in
        "deploy")
            deploy_scenario "$scenario"
            ;;
        "cleanup")
            cleanup_scenario "$scenario"
            ;;
        "info")
            show_deployment_info "$scenario"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
