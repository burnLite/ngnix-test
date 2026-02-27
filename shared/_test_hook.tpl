{{- define "shared.testHook" -}}
{{- if and .Values.releaseNotes. -}}
{{- $saName := printf "release-notes-%s" .Release.Name -}}
{{- $configMapName := "release-notes-versions" -}}
{{- $changelogPath := printf "%s/CHANGELOG.md" (.Template.BasePath | dir | dir) -}}
{{- $credSecret := .Values.releaseNotes.credentialsSecret -}}

apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ $saName }}
  namespace: {{ .Release.Namespace }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ $saName }}
  namespace: {{ .Release.Namespace }}
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
  namespace: {{ .Release.Namespace }}
subjects:
  - kind: ServiceAccount
    name: {{ $saName }}
    namespace: {{ .Release.Namespace }}
roleRef:
  kind: Role
  apiGroup: rbac.authorization.k8s.io
  name: {{ $saName }}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: release-notes-postsync-{{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      serviceAccountName: {{ $saName }}
      restartPolicy: Never
      initContainers:
        - name: install-tools
          image: alpine:3.19
          command:
            - sh
            - -c
            - |
              apk add --no-cache curl jq
              cp /usr/bin/curl /tools/curl
              cp /usr/bin/jq /tools/jq
          volumeMounts:
            - name: tools
              mountPath: /tools
      containers:
        - name: release-notes
          image: bitnami/kubectl:latest
          env:
            - name: NEW_VERSION
              value: "{{ .Chart.AppVersion }}"
            - name: APP_NAME
              value: "{{ .Release.Name }}"
            - name: CONFIGMAP_NAME
              value: "{{ $configMapName }}"
            - name: CHANGELOG_PATH
              value: "{{ $changelogPath }}"
            - name: BITBUCKET_WORKSPACE
              value: "{{ .Values.releaseNotes.bitbucketWorkspace }}"
            - name: BITBUCKET_REPO
              value: "{{ .Values.releaseNotes.bitbucketRepo }}"
            - name: BITBUCKET_BRANCH
              value: "{{ .Values.releaseNotes.bitbucketBranch | default "main" }}"
            - name: BITBUCKET_USERNAME
              valueFrom:
                secretKeyRef:
                  name: {{ $credSecret }}
                  key: bitbucket-username
            - name: BITBUCKET_TOKEN
              valueFrom:
                secretKeyRef:
                  name: {{ $credSecret }}
                  key: bitbucket-token
            - name: SLACK_TOKEN
              valueFrom:
                secretKeyRef:
                  name: {{ $credSecret }}
                  key: slack-token
            - name: SLACK_CHANNEL
              valueFrom:
                secretKeyRef:
                  name: {{ $credSecret }}
                  key: slack-channel
          volumeMounts:
            - name: tools
              mountPath: /tools
          command:
            - sh
            - -c
            - |
              export PATH="/tools:$PATH"

              if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+'; then
                echo "Not a versioned release ($NEW_VERSION), skipping." && exit 0
              fi

              if ! kubectl get configmap "$CONFIGMAP_NAME" > /dev/null 2>&1; then
                echo "==> ConfigMap not found, creating..."
                kubectl create configmap "$CONFIGMAP_NAME" \
                  --from-literal="${APP_NAME}=${NEW_VERSION}" 2>/dev/null || \
                kubectl patch configmap "$CONFIGMAP_NAME" \
                  --type merge \
                  -p "{\"data\":{\"${APP_NAME}\":\"${NEW_VERSION}\"}}"
                echo "==> First deploy of $APP_NAME at $NEW_VERSION, no release notes to send."
                exit 0
              fi

              OLD_VERSION=$(kubectl get configmap "$CONFIGMAP_NAME" \
                -o jsonpath="{.data.${APP_NAME}}" 2>/dev/null || echo "")

              if [ -z "$OLD_VERSION" ]; then
                echo "==> No previous version for $APP_NAME, recording $NEW_VERSION and skipping."
                kubectl patch configmap "$CONFIGMAP_NAME" \
                  --type merge \
                  -p "{\"data\":{\"${APP_NAME}\":\"${NEW_VERSION}\"}}"
                exit 0
              fi

              [ "$OLD_VERSION" = "$NEW_VERSION" ] \
                && echo "==> No version change, skipping." && exit 0

              echo "==> $APP_NAME: $OLD_VERSION -> $NEW_VERSION"

              kubectl patch configmap "$CONFIGMAP_NAME" \
                --type merge \
                -p "{\"data\":{\"${APP_NAME}\":\"${NEW_VERSION}\"}}"

              echo "==> Done."
      volumes:
        - name: tools
          emptyDir: {}
{{- end -}}
{{- end -}}
