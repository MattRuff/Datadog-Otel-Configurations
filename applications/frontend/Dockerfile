FROM node:18-alpine AS build

# Build arguments for Git information (using Datadog standard names)
ARG DD_GIT_REPOSITORY_URL
ARG DD_GIT_COMMIT_SHA

# Set environment variables for React build
ENV REACT_APP_GIT_COMMIT_SHA=${DD_GIT_COMMIT_SHA}
ENV REACT_APP_GIT_REPOSITORY_URL=${DD_GIT_REPOSITORY_URL}
ENV REACT_APP_DD_SERVICE=frontend-service

WORKDIR /app

# Copy package files first for better caching
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY src/ ./src/
COPY public/ ./public/

# Copy any .env files
COPY .env* ./

# Build the React application
RUN npm run build

# Production stage
FROM nginx:alpine

# Build arguments for Git information (for labels) - using Datadog standard names
ARG DD_GIT_REPOSITORY_URL
ARG DD_GIT_COMMIT_SHA

# Add labels for better image metadata and Datadog integration
LABEL git.commit.sha="${DD_GIT_COMMIT_SHA}"
LABEL git.repository_url="${DD_GIT_REPOSITORY_URL}"
LABEL service="frontend-service"

# Copy built application from build stage
COPY --from=build /app/build /usr/share/nginx/html

# Copy custom nginx configuration (replaces main nginx.conf)
COPY nginx.conf /etc/nginx/nginx.conf

# Create non-root user and setup directories for nginx
RUN addgroup -g 1001 -S appuser && \
    adduser -S appuser -u 1001 -G appuser && \
    # Set ownership of static files
    chown -R appuser:appuser /usr/share/nginx/html && \
    # Create writable temp directories in /tmp
    mkdir -p /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp && \
    chown -R appuser:appuser /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp && \
    # Create directory for nginx pid file
    mkdir -p /tmp/nginx && \
    chown -R appuser:appuser /tmp/nginx

USER appuser

# Expose port
EXPOSE 8080

# Start nginx with custom configuration
CMD ["nginx", "-c", "/etc/nginx/nginx.conf"]
