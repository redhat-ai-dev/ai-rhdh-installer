{{ define "rhdh.include.backstage" }}
---
apiVersion: rhdh.redhat.com/v1alpha1
kind: Backstage
metadata:
  name: ai-rh-developer-hub
  namespace: {{ .Release.Namespace }}
spec:
  application:
    replicas: 1
    route:
      enabled: true
    extraEnvs:
      secrets:
        - name: ai-rh-developer-hub-env
    appConfig:
      configMaps:
        - name: developer-hub-base-app-config
    dynamicPluginsConfigMapName: dynamic-plugins
  database:
    enableLocalDb: true
{{ end }}