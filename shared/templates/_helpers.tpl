{{- /*
Common labels
*/ -}}
{{- define "shared-helpers.labels" -}}
helm.sh/chart: {{ include "shared-helpers.chart" . }}
{{ include "shared-helpers.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- /*
Selector labels
*/ -}}
{{- define "shared-helpers.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shared-helpers.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "shared-helpers.name" . }}
{{- end }}

{{- /*
Create chart name and version
*/ -}}
{{- define "shared-helpers.chart" -}}
{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{- /*
Create a default fully qualified app name
*/ -}}
{{- define "shared-helpers.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := include "shared-helpers.name" . }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- /*
Create the name of the chart to use
*/ -}}
{{- define "shared-helpers.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
