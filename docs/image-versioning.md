# Docker Image Versioning Strategy

This document outlines the versioning strategy for Docker images in this project to maintain proper image history and enable rollbacks.

## 🏷️ **Versioning Strategy**

### **Tag Structure**
- **`latest`**: Always points to the most recent stable version
- **`vX.Y.Z`**: Semantic versioning for specific releases
  - `X` = Major version (breaking changes)
  - `Y` = Minor version (new features, backwards compatible)
  - `Z` = Patch version (bug fixes, backwards compatible)

### **Current Versions**
- **`v1.0.0`**: Initial release with basic functionality
- **`v1.1.0`**: Fixed nginx configuration for read-only filesystem
- **`latest`**: Currently points to `v1.1.0`

## 🛠️ **Building Versioned Images**

### **Automated Versioning Script**

Use the automated script for proper versioning workflow:

```bash
# Build new version (v1.2.0) while preserving current latest as v1.1.0
./scripts/build-and-push-versioned.sh --version v1.2.0 --preserve v1.1.0
```

This script will:
1. ✅ Tag current `latest` images as the preserve version
2. ✅ Push preserve version to Docker Hub
3. ✅ Build new images with the new version tag
4. ✅ Push new version to Docker Hub  
5. ✅ Update `latest` to point to the new version

### **Manual Versioning Process**

If you prefer manual control:

```bash
# 1. Tag current latest as previous version
docker tag matthewruyffelaert667/ddog-otel-configurations-frontend:latest \
           matthewruyffelaert667/ddog-otel-configurations-frontend:v1.1.0

# 2. Push previous version  
docker push matthewruyffelaert667/ddog-otel-configurations-frontend:v1.1.0

# 3. Build new version
docker build applications/frontend/ \
  -t matthewruyffelaert667/ddog-otel-configurations-frontend:v1.2.0 \
  -t matthewruyffelaert667/ddog-otel-configurations-frontend:latest

# 4. Push new version and updated latest
docker push matthewruyffelaert667/ddog-otel-configurations-frontend:v1.2.0
docker push matthewruyffelaert667/ddog-otel-configurations-frontend:latest
```

## 📦 **Available Images**

### **Frontend Service**
```
matthewruyffelaert667/ddog-otel-configurations-frontend:v1.0.0   # Initial release
matthewruyffelaert667/ddog-otel-configurations-frontend:v1.1.0   # Nginx fixes
matthewruyffelaert667/ddog-otel-configurations-frontend:latest   # → v1.1.0
```

### **API Service**
```
matthewruyffelaert667/ddog-otel-configurations-api:v1.0.0        # Initial release  
matthewruyffelaert667/ddog-otel-configurations-api:latest        # → v1.0.0
```

### **Database Service**
```
matthewruyffelaert667/ddog-otel-configurations-database:v1.0.0   # Initial release
matthewruyffelaert667/ddog-otel-configurations-database:latest   # → v1.0.0
```

## 🚀 **Deploying Specific Versions**

### **Deploy Latest Version**
```bash
# Applications automatically use :latest tag
./scripts/deploy-apps-only.sh deploy scenario1
```

### **Deploy Specific Version**
```bash
# Deploy a specific version by overriding image tags
helm upgrade --install otel-demo-apps-scenario1 helm/otel-demo \
  --namespace otel-demo-datadog \
  --create-namespace \
  --values helm/otel-demo/values-scenario1.yaml \
  --set frontend.image.tag="v1.1.0" \
  --set api.image.tag="v1.0.0" \
  --set database.image.tag="v1.0.0"
```

### **Update Running Deployment**
```bash
# Restart deployments to pull latest images
kubectl rollout restart deployment/frontend deployment/api deployment/database -n otel-demo-datadog

# Check rollout status
kubectl rollout status deployment/frontend -n otel-demo-datadog
```

## 🔄 **Rollback Strategy**

### **Rollback to Previous Version**
```bash
# Rollback frontend to v1.0.0
kubectl set image deployment/frontend frontend=matthewruyffelaert667/ddog-otel-configurations-frontend:v1.0.0 -n otel-demo-datadog

# Check rollback status
kubectl rollout status deployment/frontend -n otel-demo-datadog
```

### **Rollback Using Kubernetes History**
```bash
# View rollout history
kubectl rollout history deployment/frontend -n otel-demo-datadog

# Rollback to previous revision
kubectl rollout undo deployment/frontend -n otel-demo-datadog

# Rollback to specific revision
kubectl rollout undo deployment/frontend --to-revision=2 -n otel-demo-datadog
```

## 📋 **Version Change Log**

### **v1.1.0** (Latest)
- ✅ **Fixed**: Nginx configuration for read-only filesystem
- ✅ **Fixed**: Container startup issues with non-root user
- ✅ **Improved**: Security headers and configuration
- 🐛 **Resolves**: `mkdir() "/var/cache/nginx/client_temp" failed` error

### **v1.0.0**
- ✅ **Initial**: React frontend with mock OpenTelemetry tracing
- ✅ **Initial**: Python API and Database services with auto-instrumentation
- ✅ **Initial**: Git version tagging for source code integration
- ✅ **Initial**: Scenario-specific service naming

## 🎯 **Best Practices**

1. **Always version before building new images**
2. **Use semantic versioning for clear change communication**
3. **Test new versions in development before pushing to latest**
4. **Keep at least 2 previous versions for rollback capability**
5. **Document changes in version change log**
6. **Use specific version tags in production**

## 🔧 **Troubleshooting**

### **Check Current Image Versions**
```bash
# Check what version is currently deployed
kubectl get deployment frontend -n otel-demo-datadog -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check available versions on Docker Hub
docker search matthewruyffelaert667/ddog-otel-configurations-frontend
```

### **Force Pull Latest Image**
```bash
# Delete pods to force image pull
kubectl delete pods -l app.kubernetes.io/name=frontend -n otel-demo-datadog
```

This versioning strategy ensures you always have a clear history of changes and the ability to rollback when needed! 🚀
