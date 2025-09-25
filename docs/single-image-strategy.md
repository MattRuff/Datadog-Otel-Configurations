# Single Image Strategy with Scenario Identification

This document explains how the lab uses a single container image per service across all scenarios, with runtime configuration through environment variables, labels, and annotations.

## Overview

Instead of building separate Docker images for each scenario, this lab uses:
- **Single Container Images**: One image each for frontend, API, and database services
- **Runtime Configuration**: Scenario behavior controlled via environment variables
- **Scenario Identification**: Labels and annotations distinguish deployment patterns

## Benefits

✅ **Efficient Storage**: Reduces image storage requirements by 66%  
✅ **Faster Builds**: Single build process instead of three separate builds  
✅ **Container Best Practices**: Configuration through environment variables  
✅ **Clear Identification**: Labels and annotations make scenarios easily distinguishable  
✅ **Simplified Deployment**: Less complexity in image management  

## Implementation Details

### Container Images

All scenarios use the same images:
```
otel-demo/frontend:latest
otel-demo/api:latest  
otel-demo/database:latest
```

### Environment Variables

Each pod receives scenario-specific environment variables:

| Variable | Purpose | Examples |
|----------|---------|----------|
| `SCENARIO` | Determines service name prefix | `scenario1`, `scenario2`, `scenario3` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Configures telemetry destination | Agent vs Collector endpoints |
| `DD_GIT_COMMIT_SHA` | Git information for Datadog integration | Full commit SHA |
| `DD_GIT_REPOSITORY_URL` | Repository for source code linking | `github.com/user/repo` |

### Labels for Service Identification

Each deployment and pod gets scenario-specific labels:

```yaml
labels:
  # Standard Helm labels
  app.kubernetes.io/name: otel-demo
  app.kubernetes.io/component: api
  
  # Scenario identification labels
  otel-demo.scenario: "scenario1"
  otel-demo.deployment-pattern: "scenario1"
  otel-demo.service-type: "api"
```

### Annotations for Metadata

Rich metadata through annotations:

```yaml
annotations:
  # Scenario identification
  otel-demo.io/scenario: "scenario1"
  otel-demo.io/deployment-pattern: "scenario1"
  otel-demo.io/telemetry-target: "http://datadog-agent.datadog.svc.cluster.local:4317"
  
  # Git information
  git.commit.sha: "818f0d0db9847f0a5e9f703ed29a5f58e18010aa"
  git.repository_url: "github.com/MattRuff/Datadog-Otel-Configurations"
```

## Dynamic Service Naming

The applications read the `SCENARIO` environment variable to determine their service names:

| Scenario | Frontend Service | API Service | Database Service |
|----------|------------------|-------------|------------------|
| scenario1 | `datadog-frontend-service` | `datadog-api-service` | `datadog-database-service` |
| scenario2 | `otel-frontend-service` | `otel-api-service` | `otel-database-service` |
| scenario3 | `ddot-frontend-service` | `ddot-api-service` | `ddot-database-service` |

## Querying by Scenario

### Using kubectl with Labels

```bash
# Get all pods for scenario1
kubectl get pods -l otel-demo.scenario=scenario1 -A

# Get API services across all scenarios
kubectl get pods -l otel-demo.service-type=api -A

# Get scenario2 deployments
kubectl get deployments -l otel-demo.deployment-pattern=scenario2 -A
```

### Using kubectl with Annotations

```bash
# Describe pods with telemetry target information
kubectl get pods -o custom-columns=NAME:.metadata.name,TELEMETRY:.metadata.annotations.'otel-demo\.io/telemetry-target' -A

# Find all pods with git commit information
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.git\.commit\.sha}{"\n"}{end}' -A
```

## Configuration Examples

### Helm Values Override

You can override image tags if needed:

```yaml
# values-custom.yaml
global:
  scenario: "scenario1"
  
api:
  image:
    tag: "v1.2.3"  # Override default "latest"
    
frontend:
  image:
    tag: "v1.2.3"
    
database:
  image:
    tag: "v1.2.3"
```

### Pure Helm Deployment

```bash
helm install otel-demo helm/otel-demo \
  --values helm/otel-demo/values-scenario1.yaml \
  --set api.image.tag=latest \
  --set frontend.image.tag=latest \
  --set database.image.tag=latest
```

## Monitoring and Observability

### Datadog Service Map

In Datadog, you'll see clearly separated services:
- **Scenario 1**: `datadog-frontend-service`, `datadog-api-service`, `datadog-database-service`
- **Scenario 2**: `otel-frontend-service`, `otel-api-service`, `otel-database-service`  
- **Scenario 3**: `ddot-frontend-service`, `ddot-api-service`, `ddot-database-service`

### Kubernetes Dashboards

Use labels to create scenario-specific dashboards:
- Filter by `otel-demo.scenario=scenario1` for direct Datadog Agent pattern
- Filter by `otel-demo.scenario=scenario2` for OpenTelemetry Collector pattern
- Filter by `otel-demo.scenario=scenario3` for DDOT Collector pattern

## Troubleshooting

### Check Scenario Configuration

```bash
# Verify scenario environment variables
kubectl exec -n otel-demo-scenario1 deployment/otel-demo-api -- env | grep SCENARIO

# Check OTLP endpoint configuration  
kubectl exec -n otel-demo-scenario1 deployment/otel-demo-api -- env | grep OTEL_EXPORTER_OTLP_ENDPOINT

# Verify service naming in application logs
kubectl logs -n otel-demo-scenario1 deployment/otel-demo-api | grep "service.name"
```

### Validate Labels and Annotations

```bash
# Check deployment labels
kubectl get deployment otel-demo-api -n otel-demo-scenario1 -o yaml | grep -A 10 labels

# Check pod annotations
kubectl get pods -n otel-demo-scenario1 -l app.kubernetes.io/component=api -o yaml | grep -A 10 annotations
```

## Best Practices

1. **Consistent Labeling**: Always include scenario labels for easy filtering
2. **Meaningful Annotations**: Use annotations for metadata that doesn't affect selection
3. **Environment Variables**: Keep scenario-specific configuration in environment variables
4. **Single Source of Truth**: Use Helm values to centrally configure scenarios
5. **Clear Naming**: Use descriptive service names that indicate the scenario

This approach provides maximum flexibility while maintaining clear separation between different OpenTelemetry deployment patterns.
