{{ define "rhdh.include.plugins" }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: dynamic-plugins
data:
  dynamic-plugins.yaml: |
    includes:
      - dynamic-plugins.default.yaml
    plugins: []
{{ end }}