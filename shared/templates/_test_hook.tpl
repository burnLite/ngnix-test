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
      volumes:
        - name: tools
          emptyDir: {}
      initContainers:
        - name: install-tools
          image: alpine:3.19
          volumeMounts:
            - name: tools
              mountPath: /tools
          command:
            - sh
            - -c
            - |
              apk add --no-cache curl jq kubectl
              cp /usr/bin/curl /tools/curl
              cp /usr/bin/jq /tools/jq
      containers:
        - name: release-notes
          image: bitnami/kubectl:latest
          volumeMounts:
            - name: tools
              mountPath: /tools
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
              export PATH="/tools:$PATH"
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

              RELEASE_DATE=$(date '+%Y-%m-%d %H:%M:%S')
              
              PAYLOAD=$(jq -n \
                --arg channel "release-notes" \
                --arg text "New release deployed" \
                --arg app_name "$APP_NAME" \
                --arg new_version "$NEW_VERSION" \
                --arg release_date "$RELEASE_DATE" \
                --arg namespace "{{ .Release.Namespace }}" \
                '{
                  channel: $channel,
                  text: $text,
                  attachments: [
                    {
                      fallback: "Release notification for \($app_name) v\($new_version)",
                      color: "#36a64f",
                      pretext: "🚀 A new release has been deployed",
                      title: $app_name,
                      fields: [
                        {
                          title: "Application",
                          value: $app_name,
                          short: true
                        },
                        {
                          title: "Version",
                          value: $new_version,
                          short: true
                        },
                        {
                          title: "Release Date",
                          value: $release_date,
                          short: true
                        },
                        {
                          title: "Namespace",
                          value: $namespace,
                          short: true
                        }
                      ],
                      footer: "ArgoCD Release Bot",
                      footer_icon: "https://argoproj.github.io/argo-cd/assets/logo.png"
                    }
                  ]
                }')

              curl --location 'https://slack.com/api/chat.postMessage' \
                --header 'Content-Type: application/json' \
                --header "Authorization: Bearer $SLACK_TOKEN" \
                --data "$PAYLOAD"

              echo "==> $APP_NAME: $OLD_VERSION -> $NEW_VERSION"
              kubectl patch configmap "$CONFIGMAP_NAME" -n "$TARGET_NS" \
                --type merge -p "{\"data\":{\"${APP_NAME}\":\"${NEW_VERSION}\"}}"
              echo "==> Done."
{{- end -}}
{{- end -}}
