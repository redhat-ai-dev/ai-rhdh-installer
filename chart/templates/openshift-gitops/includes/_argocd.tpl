{{ define "rhdh.include.argocd" }}
---
apiVersion: argoproj.io/v1beta1
kind: ArgoCD
metadata:
  name: ai-rhdh-argocd
  namespace: {{ .Release.Namespace }}
spec:
  server:
    route:
      enabled: true
      tls:
        insecureEdgeTerminationPolicy: Redirect
        termination: reencrypt
  sso:
    dex:
      openShiftOAuth: true
      resources:
        limits:
          cpu: 500m
          memory: 256Mi
        requests:
          cpu: 250m
          memory: 128Mi
    provider: dex
  rbac:
    defaultPolicy: ''
    policy: |
      g, system:cluster-admins, role:admin
      g, cluster-admins, role:admin
    scopes: '[groups]'
  controller:
    processors: {}
    resources:
{{ index .Values "openshift-gitops" "argoCD" "controller" "resources" | toYaml | indent 6 }}
  extraConfig:
    accounts.admin: apiKey, login
{{ end }}