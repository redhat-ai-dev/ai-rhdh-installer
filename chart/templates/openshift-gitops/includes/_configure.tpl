{{ define "rhdh.gitops.configure" }}
- name: configure-gitops
  image: "registry.redhat.io/openshift4/ose-tools-rhel8:latest"
  workingDir: /tmp
  command:
    - /bin/sh
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      echo -n "* Installing 'argocd' CLI: "
      curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
      chmod 555 argocd
      ./argocd version --client | head -1 | cut -d' ' -f2

      CRD="argocds"
      echo -n "* Waiting for '$CRD' CRD: "
      while [ $(kubectl api-resources | grep -c "^$CRD ") = "0" ] ; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      #
      # All actions must be idempotent
      #
      CHART="rhdh"
      NAMESPACE="{{.Release.Namespace}}"
      RHDH_ARGOCD_INSTANCE="$CHART-argocd"

      echo -n "* Waiting for gitops operator deployment: "
      until kubectl get argocds.argoproj.io -n openshift-gitops openshift-gitops -o jsonpath={.status.phase} | grep -q "^Available$"; do
        echo -n "_"
        sleep 2
      done
      echo "OK"

      echo -n "* Creating ArgoCD instance: "
      cat <<EOF | kubectl apply -n "$NAMESPACE" -f - >/dev/null
      {{ include "rhdh.include.argocd" . | indent 6 }}
      EOF
{{ end }}