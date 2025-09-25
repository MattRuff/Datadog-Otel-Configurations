# OpenTelemetry + Datadog Kubernetes Lab

This lab demonstrates three different OpenTelemetry deployment patterns with Datadog using modern Kubernetes operators:

## Architecture Overview

### Scenario 1: Direct to Datadog Agent (via Datadog Operator)
```
Microservices → OTLP → Datadog Agent (Operator) → Datadog Platform
```

### Scenario 2: Via OpenTelemetry Collector (via OTel Operator)
```
Microservices → OTLP → OTel Collector (Operator) → Datadog Exporter → Datadog Platform
```

### Scenario 3: Datadog Distribution of OpenTelemetry (DDOT) Collector
```
Microservices → OTLP → Datadog Agent (DDOT Collector) → Datadog Platform
```

## Scenario Comparison

- **Scenario 1**: Traditional Datadog Agent with OTLP ingestion - simple setup, Datadog-native
- **Scenario 2**: Standalone OpenTelemetry Collector - maximum flexibility, vendor-neutral
- **Scenario 3**: DDOT Collector - combines OTel flexibility with Datadog enterprise features, includes curated components optimized for Datadog

## Services

This lab includes 3 microservices deployed via Helm with scenario-specific naming:
- **Frontend Service**: React app that makes API calls (`datadog-`, `otel-`, or `ddot-frontend-service`)
- **API Service**: Python Flask backend that processes requests (`datadog-`, `otel-`, or `ddot-api-service`)
- **Database Service**: Service that handles data operations with Redis (`datadog-`, `otel-`, or `ddot-database-service`)

## Project Structure

```
.
├── applications/              # Microservice applications
│   ├── frontend/             # React frontend service
│   ├── api/                  # Python Flask API service
│   └── database/             # Database service
├── helm/                     # Helm charts
│   └── otel-demo/           # Main application chart
├── operators/               # Operator configurations
│   ├── datadog/            # Datadog Agent Operator configs
│   └── opentelemetry/      # OpenTelemetry Operator configs
└── scripts/                # Deployment and utility scripts
    └── operators/          # Operator deployment scripts
```

## Prerequisites

- Kubernetes cluster (minikube, kind, or cloud provider)
- kubectl configured
- Helm v3 installed
- Docker for building images
- Datadog API key

## Quick Start

### 🎯 Applications Only (Recommended)

Deploy **only the microservices** in separate namespaces. The Helm chart contains no operators:

```bash
# 1. Clone this repository
git clone <repository-url>
cd gateway-lab-cursor

# 2. Deploy applications (each in its own namespace)
./scripts/deploy-apps-only.sh deploy scenario1    # → otel-demo-datadog namespace
./scripts/deploy-apps-only.sh deploy scenario2    # → otel-demo-collector namespace  
./scripts/deploy-apps-only.sh deploy scenario3    # → otel-demo-ddot namespace

# 3. Check status
./scripts/deploy-apps-only.sh status

# 4. Access applications
kubectl port-forward -n otel-demo-datadog svc/frontend-service 3000:80     # Scenario 1
kubectl port-forward -n otel-demo-collector svc/frontend-service 3001:80   # Scenario 2
kubectl port-forward -n otel-demo-ddot svc/frontend-service 3002:80        # Scenario 3
```

### 🔧 Full Deployment (Operators + Applications)

For complete setup including operators:

```bash
# 1. Set your Datadog API key
export DD_API_KEY=<your-key>

# 2. Deploy everything including operators
./scripts/deploy.sh deploy scenario1    # Full Scenario 1 setup
./scripts/deploy.sh deploy scenario2    # Full Scenario 2 setup
./scripts/deploy.sh deploy scenario3    # Full Scenario 3 setup

# 3. Check deployment status  
./scripts/deploy.sh status
```

### 📋 Direct Helm Deployment

```bash
# Set your API key
export DD_API_KEY=<your-key>

# Deploy any scenario
helm install otel-demo helm/otel-demo \
  --values helm/otel-demo/values-scenario1.yaml \
  --set global.gitCommitSha="$(git rev-parse HEAD)" \
  --set global.gitRepositoryUrl="$(git remote get-url origin | sed 's|.*://||' | sed 's|\.git$||')"
```

## Features

✅ **Three Complete Scenarios**: Compare different OpenTelemetry deployment patterns
✅ **Production-Ready**: Uses Kubernetes operators for enterprise deployment
✅ **Source Code Integration**: Git version tagging for Datadog code linking
✅ **Comprehensive Monitoring**: Traces, metrics, logs, and infrastructure
✅ **Modern Stack**: React frontend, Python APIs, Redis, full OpenTelemetry instrumentation
✅ **Single Images**: One container image per service, scenario distinguished by labels/annotations/env vars

## Operator-Based Deployment

This lab uses Kubernetes operators for production-ready deployments:
- **Datadog Agent Operator**: Manages Datadog Agent lifecycle and configuration
- **OpenTelemetry Operator**: Manages OpenTelemetry Collector deployments
- **Helm**: Manages application deployment and configuration
- **Automatic Git Tagging**: Links telemetry to source code for enhanced debugging

## 🏗️ Namespace Structure

Each scenario runs in its own isolated namespace:

| Scenario | Namespace | Description | Service Names |
|----------|-----------|-------------|---------------|
| **Scenario 1** | `otel-demo-datadog` | OTLP → Datadog Agent | `datadog-*-service` |
| **Scenario 2** | `otel-demo-collector` | OTLP → OTel Collector → Datadog | `otel-*-service` |
| **Scenario 3** | `otel-demo-ddot` | OTLP → Datadog Agent DDOT | `ddot-*-service` |

This separation allows you to:
- ✅ **Compare scenarios side-by-side**
- ✅ **Isolate configurations and troubleshoot independently**  
- ✅ **Deploy only what you need for testing**
- ✅ **Clean up individual scenarios without affecting others**

## Documentation

- 🚀 [Application Deployment Guide](docs/application-deployment.md) - Deploy just applications with namespace isolation
- 📋 [Full Deployment Guide](docs/deployment-guide.md) - Complete setup instructions with operators
- 📊 [Scenario Comparison](docs/scenario-comparison.md) - Detailed comparison of all scenarios
- 🔗 [Git Version Tagging](docs/git-version-tagging.md) - Source code integration setup
- 🐳 [Single Image Strategy](docs/single-image-strategy.md) - How scenarios use one image with runtime config
