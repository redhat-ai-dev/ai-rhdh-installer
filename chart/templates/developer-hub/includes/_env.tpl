{{ define "rhdh.include.env" }}
apiVersion: v1
kind: Secret
metadata:
    annotations:
        rhdh.redhat.com/backstage-name: ai-rh-developer-hub
    labels:
        rhdh.redhat.com/ext-config-sync: "true"
    name: ai-rh-developer-hub-env
    namespace: {{ .Release.Namespace }}
type: Opaque
data:
    NODE_TLS_REJECT_UNAUTHORIZED:  {{ "0" | b64enc }}
{{ end }}