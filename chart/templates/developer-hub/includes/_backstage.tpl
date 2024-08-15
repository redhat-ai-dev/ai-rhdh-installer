{{ define "rhdh.include.backstage" }}
---
apiVersion: rhdh.redhat.com/v1alpha1
kind: Backstage
metadata:
  name: {{index .Values "developer-hub" "name" | quote }}
  namespace: {{ .Release.Namespace }}
spec:
  application:
    replicas: 1
    route:
      enabled: true
  database:
    enableLocalDb: true
{{ end }}