{{- define "shared-helpers.testHook" -}}
{{- if and .Values.releaseNotes.enabled .Values.releaseNotes.credentialsSecret -}}
{{- $saName := printf "release-notes-%s" .Release.Name -}}
{{- $configMapName := "release-notes-versions" -}}
{{- $ns := .Release.Namespace -}}

apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ $saName }}
  namespace: {{ $ns }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ $saName }}
  namespace: {{ $ns }}
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["{{ $configMapName }}"]
    verbs: ["get", "update", "patch"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ $saName }}
  namespace: {{ $ns }}
subjects:
  - kind: ServiceAccount
    name: {{ $saName }}
    namespace: {{ $ns }}
roleRef:
  kind: Role
  apiGroup: rbac.authorization.k8s.io
  name: {{ $saName }}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: release-notes-postsync-{{ .Release.Name }}
  namespace: {{ $ns }}
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
    argocd.argoproj.io/sync-wave: "0"
spec:
  ttlSecondsAfterFinished: 86400
  template:
    spec:
      serviceAccountName: {{ $saName }}
      restartPolicy: Never
      containers:
        - name: release-notes
          image: alpine/k8s:1.29.2
          env:
            - name: NEW_VERSION
              value: "{{ .Chart.AppVersion }}"
            - name: APP_NAME
              value: "{{ .Release.Name }}"
            - name: CONFIGMAP_NAME
              value: "{{ $configMapName }}"
            - name: TARGET_NS
              value: "{{ $ns }}"
            - name: SLACK_TOKEN
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.releaseNotes.credentialsSecret }}
                  key: slack-token
          command:
            - sh
            - -c
            - |
              set -e

              if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+'; then
                echo "Not a versioned release ($NEW_VERSION), skipping."
                exit 0
              fi

              if ! kubectl get configmap "$CONFIGMAP_NAME" -n "$TARGET_NS" > /dev/null 2>&1; then
                echo "==> ConfigMap not found, creating..."
                kubectl create configmap "$CONFIGMAP_NAME" -n "$TARGET_NS" \
                  --from-literal="${APP_NAME}=${NEW_VERSION}" || true
                echo "==> First deploy of $APP_NAME at $NEW_VERSION"
                exit 0
              fi

              OLD_VERSION=$(kubectl get configmap "$CONFIGMAP_NAME" -n "$TARGET_NS" \
                -o jsonpath="{.data.${APP_NAME}}" 2>/dev/null || echo "")

              if [ -z "$OLD_VERSION" ]; then
                echo "==> No previous version for $APP_NAME, recording $NEW_VERSION"
                kubectl patch configmap "$CONFIGMAP_NAME" -n "$TARGET_NS" \
                  --type merge -p "{\"data\":{\"${APP_NAME}\":\"${NEW_VERSION}\"}}"
                exit 0
              fi

              if [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
                echo "==> No version change ($NEW_VERSION), skipping."
                exit 0
              fi

              RELEASE_DATE=$(date -u '+%Y-%m-%d %H:%M UTC')

              PAYLOAD=$(jq -n \
                --arg channel "release-notes" \
                --arg app "$APP_NAME" \
                --arg ver "$NEW_VERSION" \
                --arg date "$RELEASE_DATE" \
                --arg ns "$TARGET_NS" \
                '{
                  channel: $channel,
                  text: ("New release for " + ($app | ascii_upcase) + " deployed"),
                  attachments: [{
                    fallback: ("Release notification for " + ($app | ascii_upcase) + " v" + $ver),
                    color: "#36a64f",
                    pretext: "🚀 A new release has been deployed",
                    fields: [
                      { title: "Application",  value: $app,  short: true },
                      { title: "Version",      value: $ver,  short: true },
                      { title: "Release Date", value: $date, short: true },
                      { title: "Namespace",    value: $ns,   short: true }
                    ],
                    footer: "ArgoCD Release Bot",
                    footer_icon: "https://argoproj.github.io/argo-cd/assets/logo.png"
                  }]
                }')

              echo "==> Sending Slack notification..."
              SLACK_RESPONSE=$(curl -sf --location 'https://slack.com/api/chat.postMessage' \
                --header 'Content-Type: application/json; charset=utf-8' \
                --header "Authorization: Bearer $SLACK_TOKEN" \
                --data "$PAYLOAD")
              echo "Slack response: $SLACK_RESPONSE"

              if ! echo "$SLACK_RESPONSE" | jq -e '.ok == true' > /dev/null; then
                echo "==> Slack API error: $(echo $SLACK_RESPONSE | jq -r '.error')"
                exit 1
              fi

              echo "==> $APP_NAME: $OLD_VERSION -> $NEW_VERSION"
              kubectl patch configmap "$CONFIGMAP_NAME" -n "$TARGET_NS" \
                --type merge -p "{\"data\":{\"${APP_NAME}\":\"${NEW_VERSION}\"}}"
              echo "==> Done."
{{- end -}}
{{- end -}}
