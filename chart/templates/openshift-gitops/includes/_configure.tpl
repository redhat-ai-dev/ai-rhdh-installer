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
      until kubectl get argocds.argoproj.io -n "$NAMESPACE" "ai-$RHDH_ARGOCD_INSTANCE" --ignore-not-found -o jsonpath={.status.phase} | grep -q "^Available$"; do
        echo -n "_"
        sleep 2
      done
      echo -n "."
      until kubectl get route -n "$NAMESPACE" "ai-$RHDH_ARGOCD_INSTANCE-server" >/dev/null 2>&1; do
        echo -n "_"
        sleep 2
      done
      echo "OK"

      echo -n "* ArgoCD admin user: "
      if [ "$(kubectl get secret "$RHDH_ARGOCD_INSTANCE-secret" -o name --ignore-not-found | wc -l)" = "0" ]; then
          ARGOCD_HOSTNAME="$(kubectl get route -n "$NAMESPACE" "ai-$RHDH_ARGOCD_INSTANCE-server" --ignore-not-found -o jsonpath={.spec.host})"
          echo -n "."
          ARGOCD_PASSWORD="$(kubectl get secret -n "$NAMESPACE" "ai-$RHDH_ARGOCD_INSTANCE-cluster" -o jsonpath="{.data.admin\.password}" | base64 --decode)"
          echo -n "."
          RETRY=0
          while ! ./argocd login "$ARGOCD_HOSTNAME" --grpc-web --insecure --http-retry-max 5 --username admin --password "$ARGOCD_PASSWORD"{{- if index .Values "openshift-gitops" "skip-tls" }} --skip-test-tls{{- end }}>/dev/null; do
            if [ "$RETRY" = "20" ]; then
              echo "FAIL"
              echo "[ERROR] Could not login to ArgoCD" >&2
              exit 1
            else
              echo -n "_"
              RETRY=$((RETRY + 1))
              sleep 5
            fi
          done
          echo -n "."
          ARGOCD_API_TOKEN="$(./argocd account generate-token --http-retry-max 5 --account "admin")"
          echo -n "."
          kubectl create secret generic "$RHDH_ARGOCD_INSTANCE-secret" \
            --from-literal="ARGOCD_API_TOKEN=$ARGOCD_API_TOKEN" \
            --from-literal="ARGOCD_HOSTNAME=$ARGOCD_HOSTNAME" \
            --from-literal="ARGOCD_PASSWORD=$ARGOCD_PASSWORD" \
            --from-literal="ARGOCD_USER=admin" \
            -n "$NAMESPACE" \
            > /dev/null
      fi
      echo "OK"
{{ end }}