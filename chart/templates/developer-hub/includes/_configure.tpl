{{ define "rhdh.developer-hub.configure" }}
{{ if (index .Values "developer-hub") }}
- name: configure-developer-hub
  image: "registry.redhat.io/openshift4/ose-tools-rhel8:latest"
  workingDir: /tmp
  command:
    - /bin/sh
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      echo -n "* Fetching yq: "
      curl -sL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/bin/yq && chmod +x /usr/bin/yq
      echo "OK"

      CRD="backstages"
      echo -n "* Waiting for '$CRD' CRD: "
      while [ $(kubectl api-resources | grep -c "^$CRD ") = "0" ] ; do
        echo -n "_"
        sleep 3
      done
      echo "OK"

      #
      # All actions must be idempotent
      #
      NAMESPACE="{{.Release.Namespace}}"
      APPCONFIG_CONFIGMAP="developer-hub-base-app-config"

      echo -n "* Creating RHDH Base Variables Secret: "
      cat <<EOF | kubectl apply -f - >/dev/null
      {{ include "rhdh.include.env" . | indent 6 }}
      EOF
      echo "OK"

      echo -n "* Creating RHDH Base App Config: "
      cat <<EOF | kubectl apply -f - >/dev/null
      {{ include "rhdh.include.appconfig" . | indent 6 }}
      EOF
      echo "OK"

      echo -n "* Creating RHDH instance: "
      BACKSTAGE_CR_DATA=$(mktemp)
      cat <<EOF >"${BACKSTAGE_CR_DATA}"
      {{ include "rhdh.include.backstage" . | indent 6 }}
      EOF
      cat $BACKSTAGE_CR_DATA | kubectl apply -n "$NAMESPACE" -f - >/dev/null
      echo "OK"

      echo -n "* Waiting for RHDH route: "
      BACKSTAGE_CR_NAME="$(yq '.metadata.name' $BACKSTAGE_CR_DATA)"
      until kubectl get route -n "$NAMESPACE" "backstage-${BACKSTAGE_CR_NAME}" >/dev/null 2>&1; do
        echo -n "_"
        sleep 2
      done
      echo "OK"

      echo -n "* Patching RHDH Default App Config: "
      APPCONFIG_DATA=$(mktemp)
      RHDH_URL="https://$(kubectl get route -n "$NAMESPACE" "backstage-${BACKSTAGE_CR_NAME}" --ignore-not-found -o jsonpath={.spec.host})"
      echo -n "."

      kubectl get configmap $APPCONFIG_CONFIGMAP -n $NAMESPACE -o yaml | yq '.data["app-config.base.yaml"]' > $APPCONFIG_DATA
      echo -n "."
      yq -i ".app.baseUrl = \"${RHDH_URL}\" | .backend.baseUrl = \"${RHDH_URL}\" | .backend.cors.origin = \"${RHDH_URL}\"" $APPCONFIG_DATA
      echo -n "."
      kubectl patch configmap $APPCONFIG_CONFIGMAP -n $NAMESPACE --type='merge' -p="{\"data\":{\"app-config.base.yaml\":\"$(echo "$(cat ${APPCONFIG_DATA})" | sed 's/"/\\"/g' | sed 's/$/\\n/g' | tr -d '\n')\"}}"

      echo "OK"

      # Clean up temporary files
      rm $APPCONFIG_DATA
      rm $BACKSTAGE_CR_DATA
{{ end }}
{{ end }}