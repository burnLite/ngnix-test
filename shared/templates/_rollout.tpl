{{- define "shared-helpers.rollout" -}}

{{- if .Values.rollout.enabled }}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: {{ include "shared-helpers.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "shared-helpers.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  revisionHistoryLimit: 3
  workloadRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "shared-helpers.fullname" . }}
  strategy:
    blueGreen:
      activeService: {{ .Values.service.activeServiceName }}
      previewService: {{ .Values.service.previewServiceName }}
      autoPromotionEnabled: true
      autoPromotionSeconds: {{ .Values.rollout.autoPromotionSeconds }}
      scaleDownDelaySeconds: {{ .Values.rollout.scaleDownDelaySeconds }}
{{- end -}}
{{- end -}}
