{{ define "rhdh.include.appconfig" }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: developer-hub-base-app-config
  namespace: {{ .Release.Namespace }}
data:
  app-config.base.yaml: |
    app:
      title: "Red Hat Developer Hub for AI Software Templates"
{{ end }}