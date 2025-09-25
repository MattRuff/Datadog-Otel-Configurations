# Git Version Tagging for Datadog Source Code Integration

This document explains how to implement Git version tagging for Datadog source code integration, enabling features like:

- Stack trace linking to source code
- Inline code snippets in error tracking
- PR comments with test results
- Source code previews in profiling

## Overview

We use the standard Datadog environment variables to tag telemetry data with Git information:
- `DD_GIT_REPOSITORY_URL`: Repository URL without protocol (e.g., `github.com/user/repo`)
- `DD_GIT_COMMIT_SHA`: Full Git commit SHA

## Implementation

### 1. Dockerfile Configuration

Add the following lines to your Dockerfile:

```dockerfile
# Build arguments for Git information (using Datadog standard names)
ARG DD_GIT_REPOSITORY_URL
ARG DD_GIT_COMMIT_SHA

# Set as environment variables for runtime access
ENV DD_GIT_REPOSITORY_URL=${DD_GIT_REPOSITORY_URL}
ENV DD_GIT_COMMIT_SHA=${DD_GIT_COMMIT_SHA}

# Optional: Add labels for better image metadata
LABEL git.commit.sha="${DD_GIT_COMMIT_SHA}"
LABEL git.repository_url="${DD_GIT_REPOSITORY_URL}"
```

### 2. Docker Build Command

Build your Docker images with Git information:

```bash
docker build . \
  -t my-application \
  --build-arg DD_GIT_REPOSITORY_URL=$(git remote get-url origin | sed 's|.*://||' | sed 's|\.git$||') \
  --build-arg DD_GIT_COMMIT_SHA=$(git rev-parse HEAD)
```

### 3. Application Code Integration

#### Python/Flask Applications

```python
import os
from opentelemetry.sdk.resources import Resource

def configure_otel():
    resource_attributes = {
        "service.name": "my-service",
        "service.version": "1.0.0",
        "deployment.environment": os.getenv("ENVIRONMENT", "development"),
    }
    
    # Add Git information for Datadog source code integration
    git_commit_sha = os.getenv("DD_GIT_COMMIT_SHA")
    git_repository_url = os.getenv("DD_GIT_REPOSITORY_URL")
    
    if git_commit_sha:
        resource_attributes["git.commit.sha"] = git_commit_sha
        
    if git_repository_url:
        # Ensure repository URL doesn't contain protocol
        if git_repository_url.startswith(("https://", "http://")):
            git_repository_url = git_repository_url.split("://", 1)[1]
        resource_attributes["git.repository_url"] = git_repository_url
        
    resource = Resource.create(resource_attributes)
    # ... continue with OTel setup
```

#### React/Frontend Applications

For React applications, use environment variables prefixed with `REACT_APP_`:

```dockerfile
# In Dockerfile build stage
ENV REACT_APP_GIT_COMMIT_SHA=${DD_GIT_COMMIT_SHA}
ENV REACT_APP_GIT_REPOSITORY_URL=${DD_GIT_REPOSITORY_URL}
```

```javascript
// In your OpenTelemetry configuration
const resourceAttributes = {
  [SemanticResourceAttributes.SERVICE_NAME]: 'frontend-service',
  [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
};

// Add Git information
if (process.env.REACT_APP_GIT_COMMIT_SHA) {
  resourceAttributes['git.commit.sha'] = process.env.REACT_APP_GIT_COMMIT_SHA;
}

if (process.env.REACT_APP_GIT_REPOSITORY_URL) {
  let repoUrl = process.env.REACT_APP_GIT_REPOSITORY_URL;
  if (repoUrl.startsWith('https://') || repoUrl.startsWith('http://')) {
    repoUrl = repoUrl.split('://', 2)[1];
  }
  resourceAttributes['git.repository_url'] = repoUrl;
}
```

## Automated Script

Use the provided `scripts/capture-git-info.sh` script to automate Git information extraction:

```bash
# Export environment variables
source scripts/capture-git-info.sh export

# Create .env file
scripts/capture-git-info.sh env

# Show current Git information
scripts/capture-git-info.sh show
```

## Benefits

Once implemented, you'll get:

1. **Error Tracking**: Direct links from stack traces to source code
2. **Profiling**: Inline code snippets in flame graphs
3. **PR Comments**: Automated comments on pull requests with test results
4. **Code Context**: Better understanding of issues with source code visibility

## Best Practices

1. Always strip protocols from repository URLs
2. Use full commit SHAs, not abbreviated ones
3. Set these variables consistently across all services
4. Include Git information in both build-time and runtime environments
5. Test with your Git provider integration (GitHub, GitLab, etc.)

## Troubleshooting

- Ensure your repository URL format matches your Git provider
- Verify environment variables are set correctly in containers
- Check that Datadog has proper permissions to access your repository
- Test with a simple commit to see if linking works

For more information, see the [Datadog source code integration documentation](https://docs.datadoghq.com/integrations/guide/source-code-integration/).
