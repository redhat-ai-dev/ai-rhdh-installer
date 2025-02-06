{{ define "rhdh.include.backstage" }}
---
apiVersion: rhdh.redhat.com/v1alpha2
kind: Backstage
metadata:
  name: ai-rh-developer-hub
  namespace: {{ .Release.Namespace }}
spec:
  application:
    route:
      enabled: true
    extraEnvs:
      secrets:
        - name: ai-rh-developer-hub-env
    appConfig:
      configMaps:
        - name: developer-hub-base-app-config
  database:
    enableLocalDb: true
  deployment:
    patch:
      spec: 
        replicas: 1
{{ end }}