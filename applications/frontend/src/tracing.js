// Basic tracing setup - will be enhanced with OpenTelemetry later
// For now, just log configuration for debugging

console.log('Tracing configuration:');

// Get service name from environment variable (set by Helm)
const serviceName = process.env.REACT_APP_SERVICE_NAME || 'frontend-service';

console.log('Service Name:', serviceName);
console.log('Scenario:', process.env.REACT_APP_SCENARIO || 'default');
console.log('Git Commit SHA:', process.env.REACT_APP_GIT_COMMIT_SHA);
console.log('Git Repository URL:', process.env.REACT_APP_GIT_REPOSITORY_URL);
console.log('OTLP Endpoint:', process.env.REACT_APP_OTEL_EXPORTER_OTLP_ENDPOINT);
console.log('Environment:', process.env.REACT_APP_ENVIRONMENT || 'development');

// Export a mock SDK for compatibility
export default {
  start: () => {
    console.log('Mock tracing SDK started');
  }
};
