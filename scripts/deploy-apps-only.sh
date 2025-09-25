#!/bin/bash

# OpenTelemetry Demo - Applications Only Deployment
# This script deploys only the applications without operators
# Each scenario gets its own namespace for isolation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_info() {
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

print_status() {
    echo -e "${BLUE}[STATUS]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <command> [scenario]"
    echo ""
    echo "Commands:"
    echo "  deploy <scenario>   Deploy a specific scenario (scenario1, scenario2, scenario3)"
    echo "  deploy all          Deploy all scenarios"
    echo "  cleanup <scenario>  Remove a specific scenario"
    echo "  cleanup all         Remove all scenarios"
    echo "  list               List all deployments"
    echo "  status             Show status of all scenarios"
    echo "  help               Show this help message"
    echo ""
    echo "Scenarios:"
    echo "  scenario1          OTLP → Datadog Agent (namespace: otel-demo-datadog)"
    echo "  scenario2          OTLP → OTel Collector → Datadog (namespace: otel-demo-collector)"  
    echo "  scenario3          OTLP → Datadog Agent DDOT (namespace: otel-demo-ddot)"
    echo ""
    echo "Examples:"
    echo "  $0 deploy scenario1"
    echo "  $0 deploy all"
    echo "  $0 cleanup scenario2"
    echo "  $0 status"
}

# Function to get namespace for scenario
get_namespace() {
    local scenario=$1
    case $scenario in
        scenario1)
            echo "otel-demo-datadog"
            ;;
        scenario2)
            echo "otel-demo-collector"
            ;;
        scenario3)
            echo "otel-demo-ddot"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to get scenario description
get_scenario_description() {
    local scenario=$1
    case $scenario in
        scenario1)
            echo "OTLP → Datadog Agent"
            ;;
        scenario2)
            echo "OTLP → OpenTelemetry Collector → Datadog"
            ;;
        scenario3)
            echo "OTLP → Datadog Agent DDOT Collector"
            ;;
        *)
            echo "Unknown scenario"
            ;;
    esac
}

# Function to get OTLP endpoint for scenario (for documentation)
get_otlp_endpoint() {
    local scenario=$1
    case $scenario in
        scenario1)
            echo "http://datadog-agent.datadog.svc.cluster.local:4317"
            ;;
        scenario2)
            echo "http://otel-collector.opentelemetry.svc.cluster.local:4317"
            ;;
        scenario3)
            echo "http://datadog-agent-ddot.datadog.svc.cluster.local:4317"
            ;;
        *)
            echo "http://localhost:4317"
            ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if helm is available
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    # Check if connected to a Kubernetes cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Not connected to a Kubernetes cluster"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to deploy a scenario
deploy_scenario() {
    local scenario=$1
    local namespace=$(get_namespace "$scenario")
    local description=$(get_scenario_description "$scenario")
    
    if [ "$namespace" = "unknown" ]; then
        print_error "Unknown scenario: $scenario"
        show_usage
        exit 1
    fi
    
    print_status "Deploying $scenario: $description"
    print_info "Namespace: $namespace"
    
    # Capture Git information for source code integration
    print_status "Capturing Git information for version tagging..."
    if [ -f "scripts/capture-git-info.sh" ]; then
        source scripts/capture-git-info.sh export
    else
        print_warning "Git info script not found, skipping version tagging"
        export DD_GIT_COMMIT_SHA=""
        export DD_GIT_REPOSITORY_URL=""
    fi
    
    # Display Git information
    if [ -n "$DD_GIT_COMMIT_SHA" ]; then
        print_info "Git Commit SHA: $DD_GIT_COMMIT_SHA"
        print_info "Git Repository: $DD_GIT_REPOSITORY_URL"
    fi
    
    # Deploy via Helm using scenario-specific values
    print_status "Installing $scenario applications via Helm..."
    helm upgrade --install "otel-demo-apps-$scenario" helm/otel-demo \
        --namespace "$namespace" \
        --create-namespace \
        --values "helm/otel-demo/values-$scenario.yaml" \
        --set global.gitCommitSha="$DD_GIT_COMMIT_SHA" \
        --set global.gitRepositoryUrl="$DD_GIT_REPOSITORY_URL" \
        --wait \
        --timeout=10m
    
    print_success "$scenario deployed successfully to namespace $namespace"
    
    # Show deployment info
    show_deployment_info "$scenario"
}

# Function to show deployment information
show_deployment_info() {
    local scenario=$1
    local namespace=$(get_namespace "$scenario")
    local description=$(get_scenario_description "$scenario")
    local otlp_endpoint=$(get_otlp_endpoint "$scenario")
    
    echo ""
    print_info "=== Deployment Information for $scenario ==="
    echo "Description: $description"
    echo "Namespace: $namespace"
    echo "OTLP Endpoint: $otlp_endpoint"
    echo "Service Names: $(get_service_names "$scenario")"
    echo ""
    
    print_info "Checking pod status..."
    kubectl get pods -n "$namespace" -l app.kubernetes.io/name=otel-demo || true
    
    echo ""
    print_info "Service endpoints:"
    echo ""
    echo "To access the frontend application:"
    echo "kubectl port-forward -n $namespace svc/frontend-service 3000:80"
    echo "Then open: http://localhost:3000"
    echo ""
    echo "To access the API directly:"
    echo "kubectl port-forward -n $namespace svc/api-service 5001:80"  
    echo "Then test: curl http://localhost:5001/health"
    echo ""
    
    print_warning "Note: This deployment includes only the applications."
    print_warning "You'll need to deploy the appropriate operators separately:"
    case $scenario in
        scenario1|scenario3)
            echo "  - Datadog Agent Operator"
            ;;
        scenario2)
            echo "  - OpenTelemetry Collector Operator"
            ;;
    esac
}

# Function to get service names for scenario
get_service_names() {
    local scenario=$1
    case $scenario in
        scenario1)
            echo "datadog-frontend-service, datadog-api-service, datadog-database-service"
            ;;
        scenario2)
            echo "otel-frontend-service, otel-api-service, otel-database-service"
            ;;
        scenario3)
            echo "ddot-frontend-service, ddot-api-service, ddot-database-service"
            ;;
    esac
}

# Function to cleanup a scenario
cleanup_scenario() {
    local scenario=$1
    local namespace=$(get_namespace "$scenario")
    
    if [ "$namespace" = "unknown" ]; then
        print_error "Unknown scenario: $scenario"
        exit 1
    fi
    
    print_status "Cleaning up $scenario from namespace $namespace..."
    
    # Remove Helm release
    if helm list -n "$namespace" | grep -q "otel-demo-apps-$scenario"; then
        helm uninstall "otel-demo-apps-$scenario" -n "$namespace"
        print_success "Helm release removed"
    else
        print_warning "No Helm release found for $scenario"
    fi
    
    # Remove namespace if empty
    if kubectl get namespace "$namespace" &> /dev/null; then
        local pod_count=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l)
        if [ "$pod_count" -eq 0 ]; then
            kubectl delete namespace "$namespace"
            print_success "Empty namespace $namespace removed"
        else
            print_warning "Namespace $namespace not removed (contains other resources)"
        fi
    fi
    
    print_success "$scenario cleanup completed"
}

# Function to list all deployments
list_deployments() {
    print_info "=== OpenTelemetry Demo Deployments ==="
    echo ""
    
    for scenario in scenario1 scenario2 scenario3; do
        local namespace=$(get_namespace "$scenario")
        local description=$(get_scenario_description "$scenario")
        
        echo "Scenario: $scenario"
        echo "Description: $description" 
        echo "Namespace: $namespace"
        
        if kubectl get namespace "$namespace" &> /dev/null; then
            echo "Status: Namespace exists"
            if helm list -n "$namespace" | grep -q "otel-demo-apps-$scenario"; then
                echo "Helm Release: Installed"
            else
                echo "Helm Release: Not found"
            fi
        else
            echo "Status: Not deployed"
        fi
        echo ""
    done
}

# Function to show status of all scenarios  
show_status() {
    print_info "=== OpenTelemetry Demo Status ==="
    echo ""
    
    for scenario in scenario1 scenario2 scenario3; do
        local namespace=$(get_namespace "$scenario")
        local description=$(get_scenario_description "$scenario")
        
        echo "=== $scenario: $description ==="
        echo "Namespace: $namespace"
        
        if kubectl get namespace "$namespace" &> /dev/null; then
            echo "Pods:"
            kubectl get pods -n "$namespace" -o wide 2>/dev/null || echo "  No pods found"
            echo ""
            echo "Services:"
            kubectl get svc -n "$namespace" 2>/dev/null || echo "  No services found"
        else
            echo "Status: Not deployed"
        fi
        echo ""
    done
}

# Main script logic
case "${1:-}" in
    deploy)
        check_prerequisites
        case "${2:-}" in
            scenario1|scenario2|scenario3)
                deploy_scenario "$2"
                ;;
            all)
                for scenario in scenario1 scenario2 scenario3; do
                    deploy_scenario "$scenario"
                    echo ""
                done
                ;;
            *)
                print_error "Please specify a scenario (scenario1, scenario2, scenario3) or 'all'"
                show_usage
                exit 1
                ;;
        esac
        ;;
    cleanup)
        case "${2:-}" in
            scenario1|scenario2|scenario3)
                cleanup_scenario "$2"
                ;;
            all)
                for scenario in scenario1 scenario2 scenario3; do
                    cleanup_scenario "$scenario"
                done
                ;;
            *)
                print_error "Please specify a scenario (scenario1, scenario2, scenario3) or 'all'"
                show_usage
                exit 1
                ;;
        esac
        ;;
    list)
        list_deployments
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_error "Unknown command: ${1:-}"
        show_usage
        exit 1
        ;;
esac
