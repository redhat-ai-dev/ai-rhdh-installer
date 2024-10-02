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

      echo -n "* Creating RHDH instance: "
      BACKSTAGE_CR_DATA=$(mktemp)
      cat <<EOF >"${BACKSTAGE_CR_DATA}"
      {{ include "rhdh.include.backstage" . | indent 6 }}
      EOF
      cat $BACKSTAGE_CR_DATA | kubectl apply -n "$NAMESPACE" -f - >/dev/null
      echo "OK"

      echo -n "* Waiting for RHDH Default App Config: "
      BACKSTAGE_CR_NAME="$(yq '.metadata.name' $BACKSTAGE_CR_DATA)"
      APPCONFIG_CONFIGMAP="backstage-appconfig-${BACKSTAGE_CR_NAME}"
      echo -n "."
      while [ $(kubectl get configmap -n $NAMESPACE $APPCONFIG_CONFIGMAP | grep -c "$APPCONFIG_CONFIGMAP") = "0" ]; do
        echo -n "_"
        sleep 2
      done
      echo "OK"

      echo -n "* Patching RHDH Default App Config: "
      APPCONFIG_DATA=$(mktemp)
      CLUSTER_BASE_DOMAIN=$(kubectl get -n openshift-ingress-operator ingresscontroller default -o yaml | yq '.status.domain')
      RHDH_URL="https://backstage-${BACKSTAGE_CR_NAME}-${NAMESPACE}.${CLUSTER_BASE_DOMAIN}"
      echo -n "."

      kubectl get configmap $APPCONFIG_CONFIGMAP -n $NAMESPACE -o yaml | yq '.data["default.app-config.yaml"]' > $APPCONFIG_DATA
      echo -n "."
      yq -i ".backend.baseUrl = \"${RHDH_URL}\" | .backend.cors.origin = \"${RHDH_URL}\"" $APPCONFIG_DATA
      echo -n "."
      kubectl patch configmap $APPCONFIG_CONFIGMAP -n $NAMESPACE --type='merge' -p="{\"data\":{\"default.app-config.yaml\":\"$(echo "$(cat ${APPCONFIG_DATA})" | sed 's/"/\\"/g' | sed 's/$/\\n/g' | tr -d '\n')\"}}"

      echo "OK"

      # Clean up temporary files
      rm $APPCONFIG_DATA
      rm $BACKSTAGE_CR_DATA
{{ end }}
{{ end }}