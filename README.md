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

This lab includes 3 microservices deployed via Helm:
- **Frontend Service**: React app that makes API calls
- **API Service**: Python Flask backend that processes requests
- **Database Service**: Service that handles data operations with Redis

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

1. Clone this repository
2. Set your Datadog API key: `export DD_API_KEY=<your-key>`
3. Deploy operators: `./scripts/operators/install-operators.sh`
4. Choose your scenario:
   - Deploy Scenario 1: `./scripts/operators/deploy-scenario1.sh`
   - Deploy Scenario 2: `./scripts/operators/deploy-scenario2.sh` 
   - Deploy Scenario 3: `./scripts/operators/deploy-scenario3.sh`

## Operator-Based Deployment

This lab uses Kubernetes operators for production-ready deployments:
- **Datadog Agent Operator**: Manages Datadog Agent lifecycle
- **OpenTelemetry Operator**: Manages OTel Collector lifecycle
- **Helm**: Manages application deployment and configuration
# Datadog-Otel-Configurations
