#!/bin/bash

# Versioned Docker Image Build and Push Script
# This script implements proper versioning by:
# 1. Tagging the current 'latest' with a version before building new images
# 2. Building new images with a new version tag
# 3. Updating 'latest' to point to the new version

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

# Configuration
DOCKER_REGISTRY="matthewruyffelaert667"
SERVICES=("frontend" "api" "database")
NEW_VERSION=""
PRESERVE_CURRENT=""

# Function to show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION     Specify the new version tag (e.g., v1.1.0)"
    echo "  -p, --preserve VERSION    Tag current 'latest' with this version before building new one"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --version v1.1.0 --preserve v1.0.0"
    echo "  $0 -v v1.2.0 -p v1.1.0"
    echo ""
    echo "This script will:"
    echo "1. Tag current 'latest' images with the preserve version"
    echo "2. Push preserve version to registry"  
    echo "3. Build new images with the new version tag"
    echo "4. Push new version to registry"
    echo "5. Update 'latest' tag to point to new version"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            NEW_VERSION="$2"
            shift 2
            ;;
        -p|--preserve)
            PRESERVE_CURRENT="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate inputs
if [ -z "$NEW_VERSION" ]; then
    print_error "New version must be specified with -v or --version"
    show_usage
    exit 1
fi

if [ -z "$PRESERVE_CURRENT" ]; then
    print_error "Preserve version must be specified with -p or --preserve"
    show_usage
    exit 1
fi

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running or not accessible"
        exit 1
    fi
}

# Function to preserve current latest images
preserve_current_images() {
    print_status "Preserving current 'latest' images as $PRESERVE_CURRENT..."
    
    for service in "${SERVICES[@]}"; do
        local image_name="${DOCKER_REGISTRY}/ddog-otel-configurations-${service}"
        
        print_info "Tagging ${image_name}:latest as ${image_name}:${PRESERVE_CURRENT}"
        docker tag "${image_name}:latest" "${image_name}:${PRESERVE_CURRENT}"
        
        print_info "Pushing ${image_name}:${PRESERVE_CURRENT}"
        docker push "${image_name}:${PRESERVE_CURRENT}"
    done
    
    print_success "Current images preserved as $PRESERVE_CURRENT"
}

# Function to build new images
build_new_images() {
    print_status "Building new images with version $NEW_VERSION..."
    
    # Capture Git information for version tagging
    if [ -f "scripts/capture-git-info.sh" ]; then
        source scripts/capture-git-info.sh export
        print_info "Git Commit SHA: $DD_GIT_COMMIT_SHA"
        print_info "Git Repository: $DD_GIT_REPOSITORY_URL"
    else
        print_warning "Git info script not found, building without Git metadata"
        export DD_GIT_COMMIT_SHA=""
        export DD_GIT_REPOSITORY_URL=""
    fi
    
    for service in "${SERVICES[@]}"; do
        local image_name="${DOCKER_REGISTRY}/ddog-otel-configurations-${service}"
        
        print_status "Building $service ($NEW_VERSION)..."
        docker build "applications/${service}/" \
            -t "${image_name}:${NEW_VERSION}" \
            -t "${image_name}:latest" \
            --build-arg DD_GIT_REPOSITORY_URL="$DD_GIT_REPOSITORY_URL" \
            --build-arg DD_GIT_COMMIT_SHA="$DD_GIT_COMMIT_SHA"
        
        print_success "Built ${image_name}:${NEW_VERSION}"
    done
}

# Function to push new images
push_new_images() {
    print_status "Pushing new images..."
    
    for service in "${SERVICES[@]}"; do
        local image_name="${DOCKER_REGISTRY}/ddog-otel-configurations-${service}"
        
        print_info "Pushing ${image_name}:${NEW_VERSION}"
        docker push "${image_name}:${NEW_VERSION}"
        
        print_info "Pushing ${image_name}:latest"
        docker push "${image_name}:latest"
    done
    
    print_success "All images pushed successfully"
}

# Function to show image summary
show_summary() {
    print_info "=== Image Versioning Summary ==="
    echo ""
    echo "Preserved version: $PRESERVE_CURRENT"
    echo "New version: $NEW_VERSION"
    echo "Latest now points to: $NEW_VERSION"
    echo ""
    echo "Available versions for each service:"
    for service in "${SERVICES[@]}"; do
        echo "  ${DOCKER_REGISTRY}/ddog-otel-configurations-${service}:"
        echo "    - ${PRESERVE_CURRENT} (previous)"
        echo "    - ${NEW_VERSION} (current)"
        echo "    - latest → ${NEW_VERSION}"
    done
    echo ""
    print_info "To deploy the new version, restart your deployments:"
    echo "kubectl rollout restart deployment/frontend deployment/api deployment/database -n <namespace>"
}

# Main execution
main() {
    print_info "Starting versioned build and push process..."
    print_info "Preserve current: $PRESERVE_CURRENT"
    print_info "New version: $NEW_VERSION"
    echo ""
    
    check_docker
    preserve_current_images
    build_new_images
    push_new_images
    show_summary
    
    print_success "Versioned build and push completed successfully!"
}

# Run main function
main "$@"
