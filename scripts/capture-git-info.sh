#!/bin/bash

# Script to capture Git information for Datadog source code integration
# This script extracts git commit SHA and repository URL for version tagging

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[GIT-INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[GIT-SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[GIT-WARNING]${NC} $1"
}

# Function to get git commit SHA
get_git_commit_sha() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        GIT_COMMIT_SHA=$(git rev-parse HEAD)
        echo "$GIT_COMMIT_SHA"
    else
        print_warning "Not in a git repository, using default commit SHA"
        echo "unknown"
    fi
}

# Function to get git repository URL
get_git_repository_url() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        # Try to get remote origin URL
        if git remote get-url origin > /dev/null 2>&1; then
            GIT_REPO_URL=$(git remote get-url origin)
            
            # Remove .git suffix if present
            GIT_REPO_URL=${GIT_REPO_URL%.git}
            
            # Remove protocol for Datadog integration (https:// or http://)
            if [[ $GIT_REPO_URL == https://* ]] || [[ $GIT_REPO_URL == http://* ]]; then
                GIT_REPO_URL=$(echo "$GIT_REPO_URL" | sed 's|^https\?://||')
            fi
            
            # Handle SSH URLs (git@github.com:user/repo.git -> github.com/user/repo)
            if [[ $GIT_REPO_URL == git@* ]]; then
                GIT_REPO_URL=$(echo "$GIT_REPO_URL" | sed 's|git@\([^:]*\):\(.*\)|\1/\2|')
            fi
            
            echo "$GIT_REPO_URL"
        else
            print_warning "No git remote origin found, using default repository URL"
            echo "unknown/repository"
        fi
    else
        print_warning "Not in a git repository, using default repository URL"
        echo "unknown/repository"
    fi
}

# Function to get current branch name
get_git_branch() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
        echo "$BRANCH_NAME"
    else
        echo "unknown"
    fi
}

# Function to get git tag (if on a tagged commit)
get_git_tag() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        TAG_NAME=$(git describe --exact-match --tags HEAD 2>/dev/null || echo "")
        echo "$TAG_NAME"
    else
        echo ""
    fi
}

# Function to export git information as environment variables (using Datadog standard names)
export_git_env() {
    export DD_GIT_COMMIT_SHA="$(get_git_commit_sha)"
    export DD_GIT_REPOSITORY_URL="$(get_git_repository_url)"
}

# Function to create .env file with git information
create_env_file() {
    local env_file=${1:-.env}
    
    print_info "Creating environment file: $env_file"
    
    {
        echo "# Git information for Datadog source code integration"
        echo "# Generated on $(date)"
        echo "DD_GIT_COMMIT_SHA=$(get_git_commit_sha)"
        echo "DD_GIT_REPOSITORY_URL=$(get_git_repository_url)"
        echo ""
        echo "# React app environment variables (for frontend)"
        echo "REACT_APP_GIT_COMMIT_SHA=$(get_git_commit_sha)"
        echo "REACT_APP_GIT_REPOSITORY_URL=$(get_git_repository_url)"
        echo "REACT_APP_DD_SERVICE=frontend-service"
    } > "$env_file"
    
    print_success "Environment file created: $env_file"
}

# Function to display git information
show_git_info() {
    print_info "Git Information Summary (for Datadog source code integration):"
    echo "  Commit SHA: $(get_git_commit_sha)"
    echo "  Repository URL: $(get_git_repository_url)"
}

# Main function
main() {
    case "${1:-show}" in
        "export")
            export_git_env
            print_success "Git environment variables exported"
            ;;
        "env")
            create_env_file "${2:-.env}"
            ;;
        "show")
            show_git_info
            ;;
        *)
            echo "Usage: $0 [export|env|show] [env_file]"
            echo "  export    - Export git information as environment variables"
            echo "  env       - Create .env file with git information"
            echo "  show      - Display git information (default)"
            echo ""
            echo "Examples:"
            echo "  $0 show                     # Display git information"
            echo "  $0 export                   # Export as environment variables"
            echo "  $0 env                      # Create .env file"
            echo "  $0 env deployment.env       # Create specific env file"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
