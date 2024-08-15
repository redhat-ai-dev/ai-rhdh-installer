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

      CRD="backstages"
      echo -n "* Waiting for '$CRD' CRD: "
      while [ $(kubectl api-resources | grep -c "^$CRD ") = "0" ] ; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      #
      # All actions must be idempotent
      #
      NAMESPACE="{{.Release.Namespace}}"

      echo -n "* Creating RHDH instance: "
      cat <<EOF | kubectl apply -n "$NAMESPACE" -f - >/dev/null
      {{ include "rhdh.include.backstage" . | indent 6 }}
      EOF
{{ end }}
{{ end }}