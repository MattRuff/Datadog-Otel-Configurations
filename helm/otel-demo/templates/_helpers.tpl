{{/*
Expand the name of the chart.
*/}}
{{- define "otel-demo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "otel-demo.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "otel-demo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "otel-demo.labels" -}}
helm.sh/chart: {{ include "otel-demo.chart" . }}
{{ include "otel-demo.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "otel-demo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "otel-demo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Frontend labels
*/}}
{{- define "otel-demo.frontend.labels" -}}
{{ include "otel-demo.labels" . }}
app.kubernetes.io/component: frontend
{{- end }}

{{/*
Frontend selector labels
*/}}
{{- define "otel-demo.frontend.selectorLabels" -}}
{{ include "otel-demo.selectorLabels" . }}
app.kubernetes.io/component: frontend
{{- end }}

{{/*
API labels
*/}}
{{- define "otel-demo.api.labels" -}}
{{ include "otel-demo.labels" . }}
app.kubernetes.io/component: api
{{- end }}

{{/*
API selector labels
*/}}
{{- define "otel-demo.api.selectorLabels" -}}
{{ include "otel-demo.selectorLabels" . }}
app.kubernetes.io/component: api
{{- end }}

{{/*
Database labels
*/}}
{{- define "otel-demo.database.labels" -}}
{{ include "otel-demo.labels" . }}
app.kubernetes.io/component: database
{{- end }}

{{/*
Database selector labels
*/}}
{{- define "otel-demo.database.selectorLabels" -}}
{{ include "otel-demo.selectorLabels" . }}
app.kubernetes.io/component: database
{{- end }}

{{/*
Redis labels
*/}}
{{- define "otel-demo.redis.labels" -}}
{{ include "otel-demo.labels" . }}
app.kubernetes.io/component: redis
{{- end }}

{{/*
Redis selector labels
*/}}
{{- define "otel-demo.redis.selectorLabels" -}}
{{ include "otel-demo.selectorLabels" . }}
app.kubernetes.io/component: redis
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "otel-demo.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "otel-demo.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get OTLP endpoint for scenario
*/}}
{{- define "otel-demo.otlpEndpoint" -}}
{{- if eq .Values.global.scenario "scenario1" -}}
http://datadog-agent.datadog.svc.cluster.local:4317
{{- else if eq .Values.global.scenario "scenario2" -}}
http://otel-collector.opentelemetry.svc.cluster.local:4317
{{- else if eq .Values.global.scenario "scenario3" -}}
http://datadog-agent-ddot.datadog.svc.cluster.local:4317
{{- else -}}
{{ .Values.global.otelEndpoint | default "http://localhost:4317" }}
{{- end -}}
{{- end }}

{{/*
Get service name with scenario prefix
*/}}
{{- define "otel-demo.serviceName" -}}
{{- $scenario := .scenario -}}
{{- $service := .service -}}
{{- if eq $scenario "scenario1" -}}
datadog-{{ $service }}
{{- else if eq $scenario "scenario2" -}}
otel-{{ $service }}
{{- else if eq $scenario "scenario3" -}}
ddot-{{ $service }}
{{- else -}}
{{ $service }}
{{- end -}}
{{- end }}

{{/*
Common environment variables for Git information
*/}}
{{- define "otel-demo.gitEnvVars" -}}
{{- if .Values.global.gitCommitSha }}
- name: DD_GIT_COMMIT_SHA
  value: {{ .Values.global.gitCommitSha | quote }}
{{- end }}
{{- if .Values.global.gitRepositoryUrl }}
- name: DD_GIT_REPOSITORY_URL
  value: {{ .Values.global.gitRepositoryUrl | quote }}
{{- end }}
{{- end }}

{{/*
Common OpenTelemetry environment variables
*/}}
{{- define "otel-demo.otelEnvVars" -}}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ include "otel-demo.otlpEndpoint" . | quote }}
- name: OTEL_RESOURCE_ATTRIBUTES
  value: "service.version={{ .Chart.AppVersion }},deployment.environment={{ .Values.global.environment }},scenario={{ .Values.global.scenario }}"
- name: SCENARIO
  value: {{ .Values.global.scenario | quote }}
{{- end }}
