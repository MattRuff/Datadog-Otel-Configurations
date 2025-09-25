# Application Deployment Guide

This guide shows how to deploy **only the applications** without operators, with each scenario isolated in its own namespace.

## 🏗️ Namespace Structure

Each scenario runs in its own namespace for complete isolation:

| Scenario | Namespace | Description | OTLP Target |
|----------|-----------|-------------|-------------|
| **Scenario 1** | `otel-demo-datadog` | OTLP → Datadog Agent | `datadog-agent.datadog.svc.cluster.local:4317` |
| **Scenario 2** | `otel-demo-collector` | OTLP → OTel Collector → Datadog | `otel-collector.opentelemetry.svc.cluster.local:4317` |
| **Scenario 3** | `otel-demo-ddot` | OTLP → Datadog Agent DDOT | `datadog-agent-ddot.datadog.svc.cluster.local:4317` |

## 🚀 Quick Start - Applications Only

### Deploy a Single Scenario

```bash
# Deploy Scenario 1 (OTLP → Datadog Agent)
./scripts/deploy-apps-only.sh deploy scenario1

# Deploy Scenario 2 (OTLP → OTel Collector → Datadog)  
./scripts/deploy-apps-only.sh deploy scenario2

# Deploy Scenario 3 (OTLP → Datadog Agent DDOT)
./scripts/deploy-apps-only.sh deploy scenario3
```

### Deploy All Scenarios

```bash
# Deploy all three scenarios in separate namespaces
./scripts/deploy-apps-only.sh deploy all
```

### Check Status

```bash
# Show status of all scenarios
./scripts/deploy-apps-only.sh status

# List all deployments
./scripts/deploy-apps-only.sh list
```

### Cleanup

```bash
# Remove a specific scenario
./scripts/deploy-apps-only.sh cleanup scenario1

# Remove all scenarios
./scripts/deploy-apps-only.sh cleanup all
```

## 🎯 Service Names by Scenario

Each scenario uses **scenario-specific service names** for easy identification:

### Scenario 1: `otel-demo-datadog` namespace
- 🌐 **Frontend**: `datadog-frontend-service`
- 🔌 **API**: `datadog-api-service` 
- 💾 **Database**: `datadog-database-service`
- 📊 **Redis**: `redis-service`

### Scenario 2: `otel-demo-collector` namespace  
- 🌐 **Frontend**: `otel-frontend-service`
- 🔌 **API**: `otel-api-service`
- 💾 **Database**: `otel-database-service`  
- 📊 **Redis**: `redis-service`

### Scenario 3: `otel-demo-ddot` namespace
- 🌐 **Frontend**: `ddot-frontend-service`
- 🔌 **API**: `ddot-api-service`
- 💾 **Database**: `ddot-database-service`
- 📊 **Redis**: `redis-service`

## 🔗 Accessing Applications

### Frontend Application

```bash
# Scenario 1
kubectl port-forward -n otel-demo-datadog svc/frontend-service 3000:80

# Scenario 2  
kubectl port-forward -n otel-demo-collector svc/frontend-service 3001:80

# Scenario 3
kubectl port-forward -n otel-demo-ddot svc/frontend-service 3002:80
```

Then open:
- Scenario 1: http://localhost:3000
- Scenario 2: http://localhost:3001  
- Scenario 3: http://localhost:3002

### API Health Check

```bash
# Scenario 1
kubectl port-forward -n otel-demo-datadog svc/api-service 5001:80
curl http://localhost:5001/health

# Scenario 2
kubectl port-forward -n otel-demo-collector svc/api-service 5002:80
curl http://localhost:5002/health

# Scenario 3  
kubectl port-forward -n otel-demo-ddot svc/api-service 5003:80
curl http://localhost:5003/health
```

## 📋 Direct Helm Deployment

You can also deploy directly with Helm:

```bash
# Scenario 1: Datadog Agent target
helm upgrade --install otel-demo-apps-scenario1 helm/otel-demo \
  --namespace otel-demo-datadog \
  --create-namespace \
  --values helm/otel-demo/values-scenario1.yaml

# Scenario 2: OTel Collector target
helm upgrade --install otel-demo-apps-scenario2 helm/otel-demo \
  --namespace otel-demo-collector \
  --create-namespace \
  --values helm/otel-demo/values-scenario2.yaml

# Scenario 3: DDOT Collector target  
helm upgrade --install otel-demo-apps-scenario3 helm/otel-demo \
  --namespace otel-demo-ddot \
  --create-namespace \
  --values helm/otel-demo/values-scenario3.yaml
```

## 🔧 Configuration Details

### Auto-Instrumentation

All Python services use **OpenTelemetry auto-instrumentation**:

```bash
# Runtime command in containers
opentelemetry-instrument python app.py
```

**Automatically instruments**:
- ✅ Flask web framework
- ✅ HTTP requests (requests library)
- ✅ Redis operations
- ✅ Database connections
- ✅ And many more libraries!

### Environment Variables

Each application receives scenario-specific configuration:

```yaml
# Example for Scenario 1 (datadog)
env:
  - name: SCENARIO
    value: "scenario1"
  - name: OTEL_SERVICE_NAME  
    value: "datadog-api-service"
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://datadog-agent.datadog.svc.cluster.local:4317"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "service.version=1.0.0,deployment.environment=development,scenario=scenario1,git.commit.sha=abc123"
```

### Git Version Tagging

The deployment automatically captures Git information for **Datadog source code integration**:

- **`DD_GIT_COMMIT_SHA`**: Current Git commit hash
- **`DD_GIT_REPOSITORY_URL`**: Repository URL for code linking
- **Resource attributes**: Added to telemetry for source code correlation

## ⚠️ Important Notes

### 1. Operators Required Separately

This deployment includes **only the applications** (frontend, API, database, Redis). The Datadog Agent and OpenTelemetry Collector templates have been completely removed from the Helm chart. You must install operators manually before deploying:

**Scenario 1 - Datadog Agent**:
```bash
# Install Datadog Agent Operator
helm repo add datadog https://helm.datadoghq.com
helm repo update
helm install datadog-operator datadog/datadog-operator

# Deploy Datadog Agent with OTLP enabled
kubectl apply -f - <<EOF
apiVersion: datadoghq.com/v2alpha1
kind: DatadogAgent
metadata:
  name: datadog-agent
  namespace: datadog
spec:
  global:
    credentials:
      apiSecret:
        secretName: datadog-secret
        keyName: api-key
    site: datadoghq.com
  features:
    otlp:
      receiver:
        protocols:
          grpc:
            enabled: true
            endpoint: 0.0.0.0:4317
          http:
            enabled: true
            endpoint: 0.0.0.0:4318
EOF
```

**Scenario 2 - OpenTelemetry Collector**:
```bash
# Install OpenTelemetry Operator
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml

# Deploy OpenTelemetry Collector with Datadog exporter
kubectl apply -f - <<EOF
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: otel-collector
  namespace: opentelemetry
spec:
  mode: deployment
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    exporters:
      datadog:
        api:
          site: datadoghq.com
          key: \${DD_API_KEY}
    service:
      pipelines:
        traces:
          receivers: [otlp]
          exporters: [datadog]
EOF
```

**Scenario 3 - Datadog Agent with DDOT**:
```bash
# Install Datadog Agent Operator (same as Scenario 1)
helm repo add datadog https://helm.datadoghq.com
helm repo update
helm install datadog-operator datadog/datadog-operator

# Deploy Datadog Agent with DDOT Collector enabled
kubectl apply -f - <<EOF
apiVersion: datadoghq.com/v2alpha1
kind: DatadogAgent
metadata:
  name: datadog-agent-ddot
  namespace: datadog
spec:
  global:
    credentials:
      apiSecret:
        secretName: datadog-secret
        keyName: api-key
    site: datadoghq.com
  features:
    otlp:
      receiver:
        protocols:
          grpc:
            enabled: true
            endpoint: 0.0.0.0:4317
          http:
            enabled: true
            endpoint: 0.0.0.0:4318
    otelCollector:
      enabled: true
EOF
```

### 2. Datadog Secrets

Create Datadog API key secret before deployment:

```bash
kubectl create secret generic datadog-secret \
  --from-literal=api-key=YOUR_DATADOG_API_KEY \
  --from-literal=app-key=YOUR_DATADOG_APP_KEY \
  --namespace SCENARIO_NAMESPACE
```

### 3. Docker Images

Applications use pre-built images from Docker Hub:
- `matthewruyffelaert667/ddog-otel-configurations-frontend:latest`
- `matthewruyffelaert667/ddog-otel-configurations-api:latest`  
- `matthewruyffelaert667/ddog-otel-configurations-database:latest`

## 🔍 Monitoring & Debugging

### Check Pod Logs

```bash
# Scenario 1
kubectl logs -n otel-demo-datadog deployment/api -f

# Scenario 2  
kubectl logs -n otel-demo-collector deployment/api -f

# Scenario 3
kubectl logs -n otel-demo-ddot deployment/api -f
```

### Verify Telemetry Configuration

Look for auto-instrumentation startup messages:

```
=== API Service Configuration ===
Service Name: datadog-api-service
Scenario: scenario1
OTLP Endpoint: http://datadog-agent.datadog.svc.cluster.local:4317
Git Commit SHA: abc123def456
Git Repository URL: github.com/user/repo
=================================
```

### Test Inter-Service Communication

```bash
# Get API service URL and test database calls
kubectl exec -n otel-demo-datadog deployment/api -- curl localhost:5001/api/users
```

## 🎭 Scenario Comparison

| Feature | Scenario 1 | Scenario 2 | Scenario 3 |
|---------|------------|-------------|------------|
| **Telemetry Path** | App → Datadog Agent | App → OTel Collector → Datadog | App → Datadog Agent DDOT |
| **Namespace** | `otel-demo-datadog` | `otel-demo-collector` | `otel-demo-ddot` |
| **Service Prefix** | `datadog-*` | `otel-*` | `ddot-*` |
| **Best For** | Simple Datadog setup | Multi-vendor telemetry | Datadog with OTel standards |
| **Complexity** | Low | Medium | Medium |

Choose the scenario that best fits your observability architecture! 🚀
