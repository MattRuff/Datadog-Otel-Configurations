# OpenTelemetry + Datadog Lab Deployment Guide

This guide provides step-by-step instructions for deploying the OpenTelemetry + Datadog demonstration lab.

## Prerequisites

### Required Tools
- **Kubernetes cluster** (minikube, kind, Docker Desktop, or cloud provider)
- **kubectl** (v1.19+)
- **Helm** (v3.0+)
- **Docker** (for building images)
- **Git** (for version tagging)

### Datadog Account
- Datadog account with API access
- API key (required)
- Application key (optional but recommended)

### Verify Prerequisites

```bash
# Check Kubernetes connection
kubectl cluster-info

# Check Helm installation
helm version

# Check Docker installation
docker --version

# Check Git installation
git --version
```

## Quick Start (5 minutes)

1. **Set your Datadog API key:**
   ```bash
   export DD_API_KEY=<your-datadog-api-key>
   export DD_APP_KEY=<your-datadog-app-key>  # Optional
   ```

2. **Deploy any scenario with one command:**
   ```bash
   # Choose one:
   ./scripts/deploy.sh scenario1   # Direct to Datadog Agent
   ./scripts/deploy.sh scenario2   # Via OpenTelemetry Collector
   ./scripts/deploy.sh scenario3   # DDOT Collector
   ```

3. **Access the application:**
   ```bash
   kubectl port-forward -n otel-demo-scenario1 svc/frontend-service 3000:80
   ```
   Open: http://localhost:3000

### Alternative: Pure Helm Deployment

For minimal scripting, use Helm directly:
```bash
# Set your API key
export DD_API_KEY=<your-key>

# Deploy scenario 1 (or scenario2/scenario3)
helm install otel-demo helm/otel-demo \
  --values helm/otel-demo/values-scenario1.yaml \
  --set global.gitCommitSha="$(git rev-parse HEAD)" \
  --set global.gitRepositoryUrl="$(git remote get-url origin | sed 's|.*://||' | sed 's|\.git$||')"
```

## Detailed Deployment

### Step 1: Environment Setup

#### Option A: Local Kubernetes (Recommended for Testing)

**Using minikube:**
```bash
minikube start --cpus=4 --memory=8192 --kubernetes-version=v1.28.0
```

**Using kind:**
```bash
kind create cluster --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
  - containerPort: 443
    hostPort: 8443
EOF
```

#### Option B: Cloud Kubernetes

**GKE:**
```bash
gcloud container clusters create otel-lab \
    --num-nodes=3 \
    --machine-type=e2-standard-2 \
    --zone=us-central1-a
```

**EKS:**
```bash
eksctl create cluster --name otel-lab --nodes 3 --node-type t3.medium
```

**AKS:**
```bash
az aks create --resource-group myResourceGroup --name otel-lab \
    --node-count 3 --node-vm-size Standard_B2s --generate-ssh-keys
```

### Step 2: Configure Datadog Credentials

Create a secure way to store your Datadog credentials:

```bash
# Export environment variables
export DD_API_KEY=<your-datadog-api-key>
export DD_APP_KEY=<your-datadog-app-key>  # Optional

# Verify they're set
echo $DD_API_KEY | cut -c1-8  # Should show first 8 characters
```

### Step 3: Install Operators

The lab uses Kubernetes operators for production-ready deployments:

```bash
# Install both Datadog and OpenTelemetry operators
./scripts/operators/install-operators.sh

# Check installation status
./scripts/operators/install-operators.sh status
```

This script will:
- Install Datadog Agent Operator via Helm
- Install OpenTelemetry Operator from GitHub releases
- Install cert-manager (required for OTel Operator)
- Create necessary namespaces and secrets

### Step 4: Choose and Deploy Scenario

#### Scenario 1: Direct to Datadog Agent

**Best for:** Simplicity, Datadog-native features, resource efficiency

```bash
./scripts/deploy.sh scenario1
```

**What this deploys:**
- Datadog Agent with OTLP receiver enabled
- 3 microservices with `datadog-` prefix (datadog-frontend-service, datadog-api-service, datadog-database-service)
- Redis for data storage
- Full source code integration

#### Scenario 2: Via OpenTelemetry Collector

**Best for:** Vendor neutrality, flexible processing, multi-vendor export

```bash
./scripts/deploy.sh scenario2
```

**What this deploys:**
- OpenTelemetry Collector with Datadog exporter
- Datadog Agent for infrastructure monitoring (APM disabled)
- 3 microservices with `otel-` prefix (otel-frontend-service, otel-api-service, otel-database-service)
- Redis for data storage

#### Scenario 3: DDOT Collector

**Best for:** OTel flexibility with Datadog enterprise features

```bash
./scripts/deploy.sh scenario3
```

**What this deploys:**
- Datadog Agent with DDOT Collector enabled
- Enhanced Kubernetes attribute processing
- 3 microservices with `ddot-` prefix (ddot-frontend-service, ddot-api-service, ddot-database-service)
- Redis for data storage

### Step 5: Verify Deployment

#### Check Pod Status

```bash
# Check operators
kubectl get pods -n datadog
kubectl get pods -n opentelemetry-operator-system

# Check applications (replace scenario1 with your chosen scenario)
kubectl get pods -n otel-demo-scenario1
```

#### Check Services

```bash
# List all services
kubectl get svc -n otel-demo-scenario1

# Check service endpoints
kubectl describe svc frontend-service -n otel-demo-scenario1
```

#### Verify Telemetry Flow

```bash
# Check Datadog Agent logs
kubectl logs -n datadog -l app.kubernetes.io/name=datadog-agent -f

# Check OpenTelemetry Collector logs (Scenario 2)
kubectl logs -n opentelemetry -l app.kubernetes.io/name=otel-collector -f

# Check application logs
kubectl logs -n otel-demo-scenario1 -l app.kubernetes.io/component=api
```

### Step 6: Access Applications

#### Frontend Application

```bash
kubectl port-forward -n otel-demo-scenario1 svc/frontend-service 3000:80
```
Open: http://localhost:3000

#### API Service

```bash
kubectl port-forward -n otel-demo-scenario1 svc/api-service 5001:80
```
Test: `curl http://localhost:5001/health`

#### Direct Database Access

```bash
kubectl port-forward -n otel-demo-scenario1 svc/database-service 5002:5002
```
Test: `curl http://localhost:5002/health`

## Monitoring and Observability

### Datadog Dashboard

1. **Log into Datadog**: https://app.datadoghq.com
2. **Check APM Services**: Navigate to APM → Services
3. **View Traces**: APM → Traces
4. **Monitor Infrastructure**: Infrastructure → Map
5. **Check Logs**: Logs → Search

### Expected Telemetry Data

**Traces:**
- HTTP requests between frontend, API, and database services
- Redis operations
- Full distributed trace spans

**Metrics:**
- Application performance metrics
- Infrastructure metrics (CPU, memory, disk)
- Custom business metrics

**Logs:**
- Application logs from all services
- Infrastructure logs
- Error tracking

### Source Code Integration

With Git version tagging enabled, you should see:
- Direct links from stack traces to source code
- Inline code snippets in error tracking
- Enhanced debugging capabilities

## Troubleshooting

### Common Issues

#### 1. Operators Not Installing

```bash
# Check cluster permissions
kubectl auth can-i create deployments --all-namespaces

# Check if cluster has sufficient resources
kubectl top nodes
```

#### 2. Pods Stuck in Pending

```bash
# Check resource constraints
kubectl describe pod <pod-name> -n <namespace>

# Check if persistent volumes are available
kubectl get pv
```

#### 3. No Telemetry Data in Datadog

```bash
# Verify API key is correct
kubectl get secret datadog-secret -n datadog -o yaml

# Check agent connectivity
kubectl exec -n datadog -l app.kubernetes.io/name=datadog-agent -- agent status

# Verify OTLP endpoints
kubectl get svc -n datadog
kubectl get svc -n opentelemetry
```

#### 4. Application Connectivity Issues

```bash
# Check service discovery
kubectl get endpoints -n otel-demo-scenario1

# Test internal connectivity
kubectl run test-pod --image=curlimages/curl:7.85.0 --rm -i --tty -- sh
# Then inside the pod: curl http://api-service.otel-demo-scenario1.svc.cluster.local/health
```

### Getting Help

1. **Check pod logs:**
   ```bash
   kubectl logs <pod-name> -n <namespace>
   ```

2. **Describe resources:**
   ```bash
   kubectl describe <resource-type> <resource-name> -n <namespace>
   ```

3. **Check events:**
   ```bash
   kubectl get events -n <namespace> --sort-by=.metadata.creationTimestamp
   ```

## Cleanup

### Remove Specific Scenario

```bash
# Remove scenario deployment using the deploy script
./scripts/deploy.sh scenario1 cleanup

# Or use Helm directly
helm uninstall otel-demo-scenario1 -n otel-demo-scenario1
kubectl delete namespace otel-demo-scenario1
```

### Remove All Operators

```bash
./scripts/operators/install-operators.sh cleanup
```

### Complete Cleanup

```bash
# Remove all scenarios
for scenario in scenario1 scenario2 scenario3; do
    helm uninstall otel-demo-$scenario -n otel-demo-$scenario 2>/dev/null || true
    kubectl delete namespace otel-demo-$scenario --ignore-not-found=true
done

# Remove operators
./scripts/operators/install-operators.sh cleanup

# Remove cert-manager (if not used elsewhere)
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

## Next Steps

1. **Explore Datadog Features**: Try different Datadog capabilities with your telemetry data
2. **Customize Configurations**: Modify the OpenTelemetry or Datadog configurations
3. **Add Custom Metrics**: Implement custom business metrics in the applications
4. **Scale Testing**: Test with higher traffic loads using tools like `hey` or `ab`
5. **Production Considerations**: Review security, resource limits, and monitoring for production deployment

## Advanced Topics

- [Git Version Tagging](git-version-tagging.md)
- [Scenario Comparison](scenario-comparison.md)
- [Custom OpenTelemetry Components](../operators/opentelemetry/)
- [Datadog Agent Configuration](../operators/datadog/)

For more information, see the individual documentation files in the `docs/` directory.
