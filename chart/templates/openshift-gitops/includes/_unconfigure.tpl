{{ define "rhdh.gitops.unconfigure" }}
- name: unconfigure-gitops
  image: "registry.redhat.io/openshift4/ose-tools-rhel8:latest"
  workingDir: /tmp
  command:
    - /bin/sh
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      #
      # All actions must be idempotent
      #
      CHART="rhdh"
      NAMESPACE="{{.Release.Namespace}}"
      RHDH_ARGOCD_INSTANCE="$CHART-argocd"

      echo -n "* Deleting ArgoCD instance: "
      cat <<EOF | kubectl delete -n "$NAMESPACE" --ignore-not-found -f - >/dev/null
      {{ include "rhdh.include.argocd" . | indent 6 }}
      EOF
      echo "OK"

      echo -n "* Deleting ArgoCD secret: "
      kubectl delete secret "$RHDH_ARGOCD_INSTANCE-secret" --ignore-not-found >/dev/null
      echo "OK"
{{ end }}