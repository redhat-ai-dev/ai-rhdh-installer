#!/bin/bash
set -u

NAMESPACE=${NAMESPACE:-"ai-rhdh"}
RHDH_DEPLOYMENT="backstage-ai-rh-developer-hub" # deployment created by rhdh operator by default
DEFAULT_PLUGIN_CONFIGMAP="backstage-dynamic-plugins-ai-rh-developer-hub" # configmap created by rhdh operator for plugins by default
BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))/.."

# load the checksum for latest lightspeed plugin
plugin_sha=$(npm view @janus-idp/backstage-plugin-lightspeed dist.integrity)

# make sure the target url ends in /v1
if ! [[ $LIGHTSPEED_TARGET =~ \/v1$ ]]; then
  LIGHTSPEED_TARGET="$LIGHTSPEED_TARGET/v1"
fi

# replace variables in temp files
cp $BASE_DIR/resources/lightspeed-*.yaml /tmp
sed -i "s,integrity:.*$,integrity: $plugin_sha," /tmp/lightspeed-plugins.yaml
sed -i "s,target:.*$,target: $LIGHTSPEED_TARGET," /tmp/lightspeed-config.yaml
sed -i "s,Authorization:.*$,Authorization: Bearer $LIGHTSPEED_TOKEN," /tmp/lightspeed-config.yaml

# apply configmaps from temp files
kubectl apply -n $NAMESPACE -f /tmp/lightspeed-config.yaml
kubectl apply -n $NAMESPACE -f /tmp/lightspeed-plugins.yaml
rm -f /tmp/lightspeed-*.yaml

# include lightspeed config in dynamic plugins config
kubectl get configmap $DEFAULT_PLUGIN_CONFIGMAP -n $NAMESPACE -o yaml | yq '.data["dynamic-plugins.yaml"]' > temp-dynamic-plugins.yaml
yq -i '.includes += ["lightspeed-plugins.yaml"] | .includes |= unique' temp-dynamic-plugins.yaml

kubectl patch configmap $DEFAULT_PLUGIN_CONFIGMAP -n $NAMESPACE \
--type='merge' \
-p="{\"data\":{\"dynamic-plugins.yaml\":\"$(echo "$(cat temp-dynamic-plugins.yaml)" | sed 's/"/\\"/g' | sed 's/$/\\n/g' | tr -d '\n')\"}}"

rm -f temp-dynamic-plugins.yaml

# mount the additional config maps to backstage deployment
kubectl get deploy $RHDH_DEPLOYMENT -n $NAMESPACE -o yaml | \
yq '.spec.template.spec.volumes += [{"name": "lightspeed-config", "configMap": {"name": "lightspeed-config", "defaultMode": 420, "optional": false}}, 
{"name": "lightspeed-plugins", "configMap": {"name": "lightspeed-plugins", "defaultMode": 420, "optional": false}}] |
.spec.template.spec.containers[0].volumeMounts += [{"name": "lightspeed-config", "readOnly": true, "mountPath": "/opt/app-root/src/lightspeed-config.yaml", "subPath": "lightspeed-config.yaml"}] |
.spec.template.spec.containers[0].args += ["--config", "/opt/app-root/src/lightspeed-config.yaml"] |
.spec.template.spec.initContainers[0].volumeMounts += [{"name": "lightspeed-plugins", "readOnly": true, "mountPath": "/opt/app-root/src/lightspeed-plugins.yaml", "subPath": "lightspeed-plugins.yaml"}]' | 
kubectl apply -f -