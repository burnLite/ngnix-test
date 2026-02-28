{{- define "shared-helpers.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "shared-helpers.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "shared-helpers.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "shared-helpers.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "shared-helpers.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.healthCheck.port }}
          {{- if .Values.healthCheck.enabled }}
          livenessProbe:
            httpGet:
              path: {{ .Values.healthCheck.path }}
              port: {{ .Values.healthCheck.port }}
            initialDelaySeconds: {{ .Values.healthCheck.liveness.initialDelaySeconds }}
            periodSeconds: {{ .Values.healthCheck.liveness.periodSeconds }}
          readinessProbe:
            httpGet:
              path: {{ .Values.healthCheck.path }}
              port: {{ .Values.healthCheck.port }}
            initialDelaySeconds: {{ .Values.healthCheck.readiness.initialDelaySeconds }}
            periodSeconds: {{ .Values.healthCheck.readiness.periodSeconds }}
          {{- end }}
{{- end -}}
