{{ define "rhdh.pipelines.configure" }}
- name: configure-pipelines
  image: "registry.redhat.io/openshift4/ose-tools-rhel9:v4.18.0-202502260503.p0.geb9bc9b.assembly.stream.el9"
  workingDir: /tmp
  command:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      echo -n "* Fetching sigstore/cosign: "
      curl -sL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o /usr/bin/cosign && chmod +x /usr/bin/cosign
      echo "OK"

      #
      # All actions MUST be idempotent
      #
      CHART="rhdh"
      PIPELINES_NAMESPACE="openshift-pipelines"

      echo -n "* Waiting for pipelines operator deployment: "
      while true; do
        kubectl wait --for=jsonpath='{.status.phase}'=Active namespace "$PIPELINES_NAMESPACE" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
          echo -n "." && sleep 3
        else
          echo "OK"
          break
        fi
      done
      until kubectl get route -n "$PIPELINES_NAMESPACE" pipelines-as-code-controller >/dev/null 2>&1; do
        echo -n "." && sleep 3
      done
      echo "OK"

      echo -n "* Configuring Chains secret: "
      SECRET="signing-secrets"
      if [ "$(kubectl get secret -n "$PIPELINES_NAMESPACE" "$SECRET" -o jsonpath='{.data}' --ignore-not-found --allow-missing-template-keys)" == "" ]; then
        # Delete secret/signing-secrets if already exists since by default cosign creates immutable secrets
        echo -n "."
        kubectl delete secrets  -n "$PIPELINES_NAMESPACE" "$SECRET" --ignore-not-found=true

        # To make this run conveniently without user input let's create a random password
        echo -n "."
        RANDOM_PASS=$( openssl rand -base64 30 )

        # Generate the key pair secret directly in the cluster.
        # The secret should be created as immutable.
        echo -n "."
        env COSIGN_PASSWORD=$RANDOM_PASS cosign generate-key-pair "k8s://$PIPELINES_NAMESPACE/$SECRET" >/dev/null
      fi
      # If the secret is not marked as immutable, make it so.
      if [ "$(kubectl get secret -n "$PIPELINES_NAMESPACE" "$SECRET" -o jsonpath='{.immutable}')" != "true" ]; then
        echo -n "."
        kubectl patch secret -n "$PIPELINES_NAMESPACE" "$SECRET" --dry-run=client -o yaml \
          --patch='{"immutable": true}' \
        | kubectl apply -f - >/dev/null
      fi
      echo "OK"

      echo
      echo "Configuration successful"
{{ end }}