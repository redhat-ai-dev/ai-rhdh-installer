{{ define "rhdh.gitops.configure" }}
- name: configure-gitops
  image: "registry.redhat.io/openshift4/ose-tools-rhel8:latest"
  workingDir: /tmp
  command:
    - /bin/sh
    - -c
    - |
      set -o nounset
      set -o pipefail

      echo "* Installing ArgoCD CLI *"
      curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
      chmod 555 argocd
      echo -n "ArgoCD CLI version: "
      ./argocd version --client | head -1 | cut -d' ' -f2

      CRD="argocds"
      echo "* Waiting for '$CRD' CRD *"
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

      echo "* Waiting for Gitops Operator Deployment *"
      until kubectl get argocds.argoproj.io -n openshift-gitops openshift-gitops -o jsonpath={.status.phase} | grep -q "^Available$"; do
        echo -n "."
        sleep 2
      done
      echo "OK"

      echo "* Creating ArgoCD Instance *"
      cat <<EOF | kubectl apply -n "$NAMESPACE" -f - >/dev/null
      {{ include "rhdh.include.argocd" . | indent 6 }}
      EOF
      echo "... Waiting for ArgoCD Instance"
      until kubectl get argocds.argoproj.io -n "$NAMESPACE" "ai-$RHDH_ARGOCD_INSTANCE" --ignore-not-found -o jsonpath={.status.phase} | grep -q "^Available$"; do
        echo -n "."
        sleep 2
      done
      echo "OK"
      echo "... Fetching ArgoCD Instance Route"
      until kubectl get route -n "$NAMESPACE" "ai-$RHDH_ARGOCD_INSTANCE-server" >/dev/null 2>&1; do
        echo -n "."
        sleep 2
      done
      echo "OK"

      echo "* Updating ArgoCD Admin User *"
      if [ "$(kubectl get secret "$RHDH_ARGOCD_INSTANCE-secret" -o name --ignore-not-found | wc -l)" = "0" ]; then
          echo "... Fetching ArgoCD Hostname"
          ARGOCD_HOSTNAME="$(kubectl get route -n "$NAMESPACE" "ai-$RHDH_ARGOCD_INSTANCE-server" --ignore-not-found -o jsonpath={.spec.host})"
          echo "OK"
          echo "... Fetching ArgoCD Password"
          ARGOCD_PASSWORD="$(kubectl get secret -n "$NAMESPACE" "ai-$RHDH_ARGOCD_INSTANCE-cluster" -o jsonpath="{.data.admin\.password}" | base64 --decode)"
          echo "OK"
          
          RETRY=0
          MAX_RETRY=20
          deadline_exceeded_tries=0
          max_deadline_exceeded_tries=5
          deadline_exceeded_thrown=0

          echo "* Logging Into ArgoCD *"
          while (( RETRY < MAX_RETRY )); do
            attempt_result=$(./argocd login "$ARGOCD_HOSTNAME" --grpc-web --insecure --http-retry-max 10 --username admin --password "$ARGOCD_PASSWORD" 2>&1)
            exit_code=$?

            if [[ $exit_code -eq 0 ]]; then
              echo "Successfully logged in to ArgoCD."
              break
            fi

            {{- if eq (index .Values "openshift-gitops" "skip-test-tls") true }}
            if echo "$attempt_result" | grep -q "context deadline exceeded"; then
              deadline_exceeded_tries=$((deadline_exceeded_tries + 1))
              if (( deadline_exceeded_tries == max_deadline_exceeded_tries )); then
                deadline_exceeded_thrown=1
                break
              fi
              echo "Context deadline exceeded thrown $deadline_exceeded_tries time(s). Retrying .."
              continue
            fi
            {{- end }}
             
            echo -n "."
            RETRY=$((RETRY + 1))
            sleep 5
          done

          if [[ "$RETRY" -eq "$MAX_RETRY" ]]; then
            echo "FAIL"
            echo "[ERROR] Could not login to  ArgoCD, retry limit reached." >&2
            exit 1
          fi

          if (( deadline_exceeded_thrown )); then
            echo "ArgoCD login experiencing 'context deadline exceeded error', auto applying '--skip-test-tls' flag."
            deadline_exceeded_tries=0
            while (( deadline_exceeded_tries < max_deadline_exceeded_tries )); do
              attempt_result=$(./argocd login "$ARGOCD_HOSTNAME" --grpc-web --insecure --http-retry-max 10 --username admin --password "$ARGOCD_PASSWORD" --skip-test-tls 2>&1)
              exit_code=$?

              if [[ $exit_code -eq 0 ]]; then
                echo "Successfully logged in to ArgoCD."
                break
              fi

              echo -n "."
              deadline_exceeded_tries=$((deadline_exceeded_tries + 1))
              sleep 5
            done
          fi

          if [[ "$deadline_exceeded_tries" -eq "$max_deadline_exceeded_tries" ]]; then
            echo "FAIL"
            echo "[ERROR] Could not login to  ArgoCD, retry limit reached." >&2
            exit 1
          fi

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