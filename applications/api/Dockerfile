FROM python:3.11-slim

# Build arguments for Git information (using Datadog standard names)
ARG DD_GIT_REPOSITORY_URL
ARG DD_GIT_COMMIT_SHA

# Set as environment variables for runtime access
ENV DD_GIT_REPOSITORY_URL=${DD_GIT_REPOSITORY_URL}
ENV DD_GIT_COMMIT_SHA=${DD_GIT_COMMIT_SHA}

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install auto-instrumentation packages
RUN opentelemetry-bootstrap -a install

# Copy application code
COPY app.py .

# Add labels for better image metadata and Datadog integration
LABEL git.commit.sha="${DD_GIT_COMMIT_SHA}"
LABEL git.repository_url="${DD_GIT_REPOSITORY_URL}"
LABEL service="api-service"

# Expose port
EXPOSE 5001

# Create non-root user
RUN adduser --disabled-password --gecos '' appuser && \
    chown -R appuser:appuser /app
USER appuser

# Run the application with OpenTelemetry auto-instrumentation
CMD ["opentelemetry-instrument", "python", "app.py"]
