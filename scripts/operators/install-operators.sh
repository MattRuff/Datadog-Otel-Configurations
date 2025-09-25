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

# Install Datadog Agent Operator
install_datadog_operator() {
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
    
    print_success "Datadog Agent Operator installed successfully"
}

# Install OpenTelemetry Operator
install_opentelemetry_operator() {
    print_status "Installing OpenTelemetry Operator..."
    
    # Create namespace for OpenTelemetry
    kubectl create namespace opentelemetry --dry-run=client -o yaml | kubectl apply -f -
    
    # Install cert-manager if not already installed (required for OTel Operator)
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
    
    print_success "OpenTelemetry Operator installed successfully"
}

# Create Datadog secret
create_datadog_secret() {
    print_status "Creating Datadog API secret..."
    
    kubectl delete secret datadog-secret -n datadog --ignore-not-found=true
    kubectl create secret generic datadog-secret \
        --from-literal=api-key="$DD_API_KEY" \
        --from-literal=app-key="${DD_APP_KEY:-}" \
        -n datadog
    
    # Also create in opentelemetry namespace for OTel Collector
    kubectl delete secret datadog-secret -n opentelemetry --ignore-not-found=true
    kubectl create secret generic datadog-secret \
        --from-literal=api-key="$DD_API_KEY" \
        --from-literal=app-key="${DD_APP_KEY:-}" \
        -n opentelemetry
    
    print_success "Datadog secrets created successfully"
}

# Show operator status
show_operator_status() {
    print_status "Checking operator status..."
    echo
    
    print_status "Datadog Operator:"
    kubectl get pods -n datadog -l app.kubernetes.io/name=datadog-operator
    echo
    
    print_status "OpenTelemetry Operator:"
    kubectl get pods -n opentelemetry-operator-system -l app.kubernetes.io/name=opentelemetry-operator
    echo
    
    print_status "Available CRDs:"
    kubectl get crd | grep -E "(datadoghq|opentelemetry)" || echo "No relevant CRDs found"
    echo
}

# Show deployment information
show_deployment_info() {
    print_status "Operator Installation Complete!"
    echo
    echo "Next Steps:"
    echo "1. Deploy Scenario 1 (Direct to Datadog Agent):"
    echo "   ./scripts/operators/deploy-scenario1.sh"
    echo
    echo "2. Deploy Scenario 2 (Via OpenTelemetry Collector):"
    echo "   ./scripts/operators/deploy-scenario2.sh"
    echo
    echo "3. Deploy Scenario 3 (DDOT Collector):"
    echo "   ./scripts/operators/deploy-scenario3.sh"
    echo
    echo "Operator Status:"
    show_operator_status
}

# Cleanup function
cleanup_operators() {
    print_status "Cleaning up operators..."
    
    # Remove Datadog Operator
    helm uninstall datadog-operator -n datadog 2>/dev/null || true
    kubectl delete namespace datadog --ignore-not-found=true
    
    # Remove OpenTelemetry Operator
    kubectl delete -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml --ignore-not-found=true
    kubectl delete namespace opentelemetry --ignore-not-found=true
    
    print_success "Operators cleanup completed"
}

# Main execution
main() {
    case "${1:-install}" in
        "install")
            check_prerequisites
            install_datadog_operator
            install_opentelemetry_operator
            create_datadog_secret
            show_deployment_info
            ;;
        "cleanup")
            cleanup_operators
            ;;
        "status")
            show_operator_status
            ;;
        *)
            echo "Usage: $0 [install|cleanup|status]"
            echo "  install - Install operators (default)"
            echo "  cleanup - Remove operators"
            echo "  status  - Show operator status"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
