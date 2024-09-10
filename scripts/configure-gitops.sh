#!/bin/bash

ARGOCD_INSTANCE_PROVIDED=${ARGOCD_INSTANCE_PROVIDED:-false}
NAMESPACE=${NAMESPACE:-"ai-rhdh"}
RHDH_DEPLOYMENT="backstage-ai-rh-developer-hub" # deployment created by rhdh operator by default
DEFAULT_PLUGIN_CONFIGMAP="backstage-dynamic-plugins-ai-rh-developer-hub" # configmap created by rhdh operator for plugins by default
DEFAULT_SECRET_NAME="rhdh-argocd-secret"

# ArgoCD Instance Created By Installer
if [[ $ARGOCD_INSTANCE_PROVIDED == "false" ]]; then
    # Add ConfigMap To Configure ArgoCD
    kubectl apply -n $NAMESPACE -f ./resources/argocd-config.yaml
    # Add COnfigMap For ArgoCD Plugins
    kubectl apply -n $NAMESPACE -f ./resources/argocd-plugins.yaml

    # Grab configmap and parse out the defined yaml file inside of its data to a temp file
    kubectl get configmap $DEFAULT_PLUGIN_CONFIGMAP -n $NAMESPACE -o yaml | yq '.data["dynamic-plugins.yaml"]' > temp-dynamic-plugins.yaml

    # Edit the temp file to include the argocd plugins
    yq -i '.includes += ["argocd-plugins.yaml"] | .includes |= unique' temp-dynamic-plugins.yaml

    # Patch the configmap that is deployed to update the defined yaml inside of it
    kubectl patch configmap $DEFAULT_PLUGIN_CONFIGMAP -n $NAMESPACE \
    --type='merge' \
    -p="{\"data\":{\"dynamic-plugins.yaml\":\"$(echo "$(cat temp-dynamic-plugins.yaml)" | sed 's/"/\\"/g' | sed 's/$/\\n/g' | tr -d '\n')\"}}"
    
    # Cleanup temp files
    rm -rf temp-dynamic-plugins.yaml

    # Add ArgoCD instance information and plugin to backstage deployment data
    kubectl get deploy $RHDH_DEPLOYMENT -n $NAMESPACE -o yaml | \
    yq '.spec.template.spec.volumes += [{"name": "argocd-config", "configMap": {"name": "argocd-config", "defaultMode": 420, "optional": false}}, 
    {"name": "argocd-plugins", "configMap": {"name": "argocd-plugins", "defaultMode": 420, "optional": false}}] |
    .spec.template.spec.containers[0].envFrom += [{"secretRef": {"name": "rhdh-argocd-secret"}}] |
    .spec.template.spec.containers[0].volumeMounts += [{"name": "argocd-config", "readOnly": true, "mountPath": "/opt/app-root/src/argocd-config.yaml", "subPath": "argocd-config.yaml"}] |
    .spec.template.spec.containers[0].args += ["--config", "/opt/app-root/src/argocd-config.yaml"] |
    .spec.template.spec.initContainers[0].volumeMounts += [{"name": "argocd-plugins", "readOnly": true, "mountPath": "/opt/app-root/src/argocd-plugins.yaml", "subPath": "argocd-plugins.yaml"}]' | 
    kubectl apply -f -
fi

# ArgoCD Instance Brought By User
# If a user is using this step it is assumed they did not use our installer so we need ALL the information required with no assumptions
if [[ $ARGOCD_INSTANCE_PROVIDED == "true" ]]; then
    # Gather ArgoCD instance information
    echo "You have chosen to provide your own ArgoCD instance"
    read -p "Enter the namespace of your RHDH and ArgoCD instance: " NAMESPACE
    read -p "Enter the deployment name of your RHDH instance: " RHDH_DEPLOYMENT
    read -p "Enter the name of the ConfigMap for your RHDH plugins: " RHDH_PLUGINS
    read -p "Enter your ArgoCD username: " ARGO_USERNAME
    read -p "Enter password for $ARGO_USERNAME: " ARGO_PASSWORD
    read -p "Enter your ArgoCD hostname: " ARGO_HOSTNAME
    read -p "Enter your ArgoCD token: " ARGO_TOKEN

    read -p "Enter a name for your ArgoCD instance: " ARGOCD_INSTANCE_NAME
    echo "Creating ArgoCD secret file"
    # Create the secret in the namespace so we can connect it to rhdh TODO: need the setup namespace input
    kubectl create secret generic "$ARGOCD_INSTANCE_NAME-secret" \
            --from-literal="ARGOCD_API_TOKEN=$ARGO_TOKEN" \
            --from-literal="ARGOCD_HOSTNAME=$ARGO_HOSTNAME" \
            --from-literal="ARGOCD_PASSWORD=$ARGO_PASSWORD" \
            --from-literal="ARGOCD_USER=$ARGO_USERNAME" \
            -n "$NAMESPACE" \
            > /dev/null
    
    echo "Applying ArgoCD ConfigMaps"
    # Create the plugin and config setup configmaps in the namespace
    kubectl apply -n $NAMESPACE -f ./resources/argocd-config.yaml
    kubectl apply -n $NAMESPACE -f ./resources/argocd-plugins.yaml
    
    # Grab configmap and parse out the defined yaml file inside of its data to a temp file
    kubectl get configmap $RHDH_PLUGINS -n $NAMESPACE -o yaml | yq '.data["dynamic-plugins.yaml"]' > temp-dynamic-plugins.yaml

    # Edit the temp file to include the argocd plugins
    yq -i '.includes += ["argocd-plugins.yaml"] | .includes |= unique' temp-dynamic-plugins.yaml

    # Patch the configmap that is deployed to update the defined yaml inside of it
    kubectl patch configmap $RHDH_PLUGINS -n $NAMESPACE \
    --type='merge' \
    -p="{\"data\":{\"dynamic-plugins.yaml\":\"$(echo "$(cat temp-dynamic-plugins.yaml)" | sed 's/"/\\"/g' | sed 's/$/\\n/g' | tr -d '\n')\"}}"
    
    # Cleanup temp files
    rm -rf temp-dynamic-plugins.yaml

    # Check if envFrom is present since Helm installs don't have this field by default
    has_field=$(kubectl get deploy $RHDH_DEPLOYMENT -n $NAMESPACE -o yaml | \
    yq '.spec.template.spec.containers[0] | has("envFrom")')

    if [[ $has_field == "false" ]]; then
        kubectl get deploy $RHDH_DEPLOYMENT -n $NAMESPACE -o yaml | \
        yq '.spec.template.spec.containers[0].envFrom = []' |
        kubectl apply -f -
    fi

    # Add ArgoCD instance information and plugin to backstage deployment data
    kubectl get deploy $RHDH_DEPLOYMENT -n $NAMESPACE -o yaml | \
    secretenv="$ARGOCD_INSTANCE_NAME-secret" yq '.spec.template.spec.volumes += [{"name": "argocd-config", "configMap": {"name": "argocd-config", "defaultMode": 420, "optional": false}}, 
    {"name": "argocd-plugins", "configMap": {"name": "argocd-plugins", "defaultMode": 420, "optional": false}}] |
    .spec.template.spec.containers[0].volumeMounts += [{"name": "argocd-config", "readOnly": true, "mountPath": "/opt/app-root/src/argocd-config.yaml", "subPath": "argocd-config.yaml"}] |
    .spec.template.spec.containers[0].args += ["--config", "/opt/app-root/src/argocd-config.yaml"] |
    .spec.template.spec.initContainers[0].volumeMounts += [{"name": "argocd-plugins", "readOnly": true, "mountPath": "/opt/app-root/src/argocd-plugins.yaml", "subPath": "argocd-plugins.yaml"}] |
    .spec.template.spec.containers[0].envFrom += [{"secretRef": {"name": env(secretenv)}}]' | 
    kubectl apply -f -
fi