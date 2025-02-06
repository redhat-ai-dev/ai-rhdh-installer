{{ define "rhdh.developer-hub.unconfigure" }}
{{ if (index .Values "developer-hub") }}
- name: unconfigure-developer-hub
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
      NAMESPACE="{{.Release.Namespace}}"

      echo -n "* Deleting RHDH instance: "
      cat <<EOF | kubectl delete -n "$NAMESPACE" -f - >/dev/null
      {{ include "rhdh.include.backstage" . | indent 6 }}
      EOF
      echo "OK"

      echo -n "* Deleting RHDH Base App Config: "
      cat <<EOF | kubectl delete -f - >/dev/null
      {{ include "rhdh.include.appconfig" . | indent 6 }}
      EOF
      echo "OK"

      echo -n "* Deleting RHDH Variables Secret: "
      cat <<EOF | kubectl delete -f - >/dev/null
      {{ include "rhdh.include.env" . | indent 6 }}
      EOF
      echo "OK"
{{ end }}
{{ end }}