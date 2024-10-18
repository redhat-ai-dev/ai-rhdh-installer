#!/bin/bash

# Constants
BACKSTAGE_CR_NAME="ai-rh-developer-hub"
DEFAULT_RHDH_DEPLOYMENT="backstage-ai-rh-developer-hub" # deployment created by rhdh operator by default
PLUGIN_CONFIGMAP="dynamic-plugins" # configmap created by rhdh operator for plugins by default
EXTRA_ENV_SECRET="ai-rh-developer-hub-env" # secret created by rhdh installer to store private env vars

# Variables
BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))/.."
CATALOGS_FILE=${CATALOGS_FILE:-"${BASE_DIR}/catalogs.yaml"}
RHDH_DEPLOYMENT="${DEFAULT_RHDH_DEPLOYMENT}"
RHDH_EXTRA_ENV_SECRET="${EXTRA_ENV_SECRET}"
RHDH_PLUGINS_CONFIGMAP="${PLUGIN_CONFIGMAP}"
NAMESPACE=${NAMESPACE:-"ai-rhdh"}
PIPELINES_NAMESPACE=${PIPELINES_NAMESPACE:-"openshift-pipelines"}
EXISTING_NAMESPACE=${EXISTING_NAMESPACE:-''}
EXISTING_DEPLOYMENT=${EXISTING_DEPLOYMENT:-''}
EXISTING_EXTRA_ENV_SECRET=${EXISTING_EXTRA_ENV_SECRET:-''}
RHDH_PLUGINS=${RHDH_PLUGINS:-''}
RHDH_INSTANCE_PROVIDED=${RHDH_INSTANCE_PROVIDED:-false}
RHDH_GITHUB_INTEGRATION=${RHDH_GITHUB_INTEGRATION:-true}
RHDH_GITLAB_INTEGRATION=${RHDH_GITLAB_INTEGRATION:-false}

# Secret variables
GITHUB__APP__ID=${GITHUB__APP__ID:-''}
GITHUB__APP__CLIENT__ID=${GITHUB__APP__CLIENT__ID:-''}
GITHUB__APP__CLIENT__SECRET=${GITHUB__APP__CLIENT__SECRET:-''}
GITHUB__APP__WEBHOOK__URL=${GITHUB__APP__WEBHOOK__URL:-''}
GITHUB__APP__WEBHOOK__SECRET=${GITHUB__APP__WEBHOOK__SECRET:-''}
GITHUB__APP__PRIVATE_KEY=${GITHUB__APP__PRIVATE_KEY:-''}
GITOPS__GIT_TOKEN=${GITOPS__GIT_TOKEN:-''}
GITLAB__APP__CLIENT__ID=${GITLAB__APP__CLIENT__ID:-''}
GITLAB__APP__CLIENT__SECRET=${GITLAB__APP__CLIENT__SECRET:-''}
GITLAB__TOKEN=${GITLAB__TOKEN:-''}
QUAY__DOCKERCONFIGJSON=${QUAY__DOCKERCONFIGJSON:-''}
QUAY__API_TOKEN=${QUAY__API_TOKEN:-''}
LIGHTSPEED_MODEL_URL=${LIGHTSPEED_MODEL_URL:-''}
LIGHTSPEED_API_TOKEN=${LIGHTSPEED_API_TOKEN:-''}

# Use existing variables if RHDH instance is provided
if [[ $RHDH_INSTANCE_PROVIDED != "true" ]] && [[ $RHDH_INSTANCE_PROVIDED != "false" ]]; then
    echo -n "RHDH_INSTANCE_PROVIDED needs to be set to either 'true' or 'false'"
    echo "FAIL"
    exit 1
elif [[ $RHDH_INSTANCE_PROVIDED == "true" ]]; then
    NAMESPACE="${EXISTING_NAMESPACE}"
    RHDH_DEPLOYMENT="${EXISTING_DEPLOYMENT}"
    RHDH_EXTRA_ENV_SECRET="${EXISTING_EXTRA_ENV_SECRET}"
    RHDH_PLUGINS_CONFIGMAP="${RHDH_PLUGINS}"
fi

# Reading secrets
# Reads secrets either from environment variables or user input
echo -n "* Reading secrets: "

# Reads GitHub secrets if enabling GitHub integration
if [[ $RHDH_GITHUB_INTEGRATION == "true" ]]; then
    # Reads GitHub Org App ID
    until [ ! -z "${GITHUB__APP__ID}" ]; do
        read -p "Enter your GitHub App ID: " GITHUB__APP__ID
        if [ -z "${GITHUB__APP__ID}" ]; then
            echo "No GitHub App ID entered, try again."
        fi
    done

    # Reads GitHub Org App Client ID
    until [ ! -z "${GITHUB__APP__CLIENT__ID}" ]; do
        read -p "Enter your GitHub App Client ID: " GITHUB__APP__CLIENT__ID
        if [ -z "${GITHUB__APP__CLIENT__ID}" ]; then
            echo "No GitHub App Client ID entered, try again."
        fi
    done

    # Reads GitHub Org App Client Secret
    until [ ! -z "${GITHUB__APP__CLIENT__SECRET}" ]; do
        read -p "Enter your GitHub App Client Secret: " GITHUB__APP__CLIENT__SECRET
        if [ -z "${GITHUB__APP__CLIENT__SECRET}" ]; then
            echo "No GitHub App Client Secret entered, try again."
        fi
    done

    # Reads GitHub Org App Webhook Secret
    until [ ! -z "${GITHUB__APP__WEBHOOK__SECRET}" ]; do
        read -p "Enter your GitHub App Webhook Secret: " GITHUB__APP__WEBHOOK__SECRET
        if [ -z "${GITHUB__APP__WEBHOOK__SECRET}" ]; then
            echo "No GitHub App Webhook Secret entered, try again."
        fi
    done

    # Reads GitHub Org App Private Key
    until [ ! -z "${GITHUB__APP__PRIVATE_KEY}" ]; do
        read -p "Enter your GitHub App Private Key (Use CTRL-D when finished): " -d $'\04' GITHUB__APP__PRIVATE_KEY
        echo ""
        if [ -z "${GITHUB__APP__PRIVATE_KEY}" ]; then
            echo "No GitHub App Private Key entered, try again."
        fi
    done
fi

# Reads GitLab secrets if enabling GitHub integration
if [[ $RHDH_GITLAB_INTEGRATION == "true" ]]; then
    # Reads GitLab App Client ID
    until [ ! -z "${GITLAB__APP__CLIENT__ID}" ]; do
        read -p "Enter your GitLab App Client ID: " GITLAB__APP__CLIENT__ID
        if [ -z "${GITLAB__APP__CLIENT__ID}" ]; then
            echo "No GitLab App Client ID entered, try again."
        fi
    done

    # Reads GitLab App Client Secret
    until [ ! -z "${GITLAB__APP__CLIENT__SECRET}" ]; do
        read -p "Enter your GitLab App Client Secret: " GITLAB__APP__CLIENT__SECRET
        if [ -z "${GITLAB__APP__CLIENT__SECRET}" ]; then
            echo "No GitLab App Client Secret entered, try again."
        fi
    done

    # Reads GitLab PAT
    until [ ! -z "${GITLAB__TOKEN}" ]; do
        read -p "Enter your GitLab Token: " GITLAB__TOKEN
        if [ -z "${GITLAB__TOKEN}" ]; then
            echo "No GitLab Token entered, try again."
        fi
    done
fi

# Reads Quay API Token
# Optional: If an API Token is not entered, there will be none provided to the developer hub app config
if [ -z "${QUAY__API_TOKEN}" ]; then
    read -p "Enter your Quay API Token (Optional): " QUAY__API_TOKEN
fi

echo "OK"

# Reads Model URL for lightspeed plugin
# Optional: If no URL is entered, lightspeed plugin will not be configured
if [ -z "${LIGHTSPEED_MODEL_URL}" ]; then
    read -p "Enter your model URL for lightspeed (Optional): " LIGHTSPEED_MODEL_URL

    # Reads API token for lightspeed plugin
    # Optional: If no token is entered, lightspeed plugin will not use authenticated communication
    if [ -z "${LIGHTSPEED_API_TOKEN}" ]; then
        read -p "Enter API token for lightspeed (Optional): " LIGHTSPEED_API_TOKEN
    fi
    echo "OK"
fi
if [ ! -z "${LIGHTSPEED_MODEL_URL}" ]; then
    # make sure the target url ends in /v1
    if ! [[ $LIGHTSPEED_MODEL_URL =~ \/v1$ ]]; then
        LIGHTSPEED_MODEL_URL="$LIGHTSPEED_MODEL_URL/v1"
    fi

    plugin_sha=$(npm view @janus-idp/backstage-plugin-lightspeed dist.integrity)
    yq -i ".plugins.[0].integrity = \"${plugin_sha}\"" $BASE_DIR/optional-plugins/lightspeed-plugins.yaml
fi

# Waiting for pipelines operator deployment
# Waits for the deployment of the pipelines services to finish before proceeding.
echo -n "* Waiting for pipelines operator deployment: "
until kubectl get namespace "${PIPELINES_NAMESPACE}" >/dev/null 2>&1; do
    echo -n "."
    sleep 3
done
until kubectl get route -n "${PIPELINES_NAMESPACE}" pipelines-as-code-controller >/dev/null 2>&1; do
    echo -n "."
    sleep 3
done
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi
echo "OK"

# Fetching Webhook URL
if [[ $RHDH_GITHUB_INTEGRATION == "true" ]]; then
    echo -n "* Fetching Webhook URL: "
    if [ -z "${GITHUB__APP__WEBHOOK__URL}" ]; then
        if [ -z "${RHDH_EXTRA_ENV_SECRET}" ]; then
            GITHUB__APP__WEBHOOK__URL="$(kubectl get routes -n "${PIPELINES_NAMESPACE}" pipelines-as-code-controller -o jsonpath="https://{.spec.host}")"
        elif [ -z "$(kubectl -n ${NAMESPACE} get secret ${RHDH_EXTRA_ENV_SECRET} --ignore-not-found -o name)" ]; then
            if [ $? -ne 0 ]; then
                echo "FAIL"
                exit 1
            fi
            echo -n "Extra environment variable secret '${RHDH_EXTRA_ENV_SECRET}' not found!"
            echo "FAIL"
            exit 1
        elif [[ "$(kubectl -n ${NAMESPACE} get secret ${RHDH_EXTRA_ENV_SECRET} -o yaml | yq '.data.GITHUB__APP__WEBHOOK__URL')" == "null" ]]; then
            if [ $? -ne 0 ]; then
                echo "FAIL"
                exit 1
            fi
            GITHUB__APP__WEBHOOK__URL="$(kubectl get routes -n "${PIPELINES_NAMESPACE}" pipelines-as-code-controller -o jsonpath="https://{.spec.host}")"
        else
            GITHUB__APP__WEBHOOK__URL="$(kubectl -n ${NAMESPACE} get secret ${RHDH_EXTRA_ENV_SECRET} -o yaml | yq '.data.GITHUB__APP__WEBHOOK__URL' | base64 -d)"
        fi
        
        if [ $? -ne 0 ]; then
            echo "FAIL"
            exit 1
        fi
    fi
    echo "OK"
fi

# Patching extra env secret
# Patches extra env var secret to include private vars passed into this script 
# and referenced by the extra app config
echo -n "* Patching extra env secret: "
EXTRA_ENV_SECRET_PATCH=$(yq -n -M -I=0 -o=json)
if [[ $RHDH_GITHUB_INTEGRATION == "true" ]]; then
    EXTRA_ENV_SECRET_PATCH=$(echo "$EXTRA_ENV_SECRET_PATCH" | yq \
        ".data.GITHUB__APP__ID = \"$(echo "${GITHUB__APP__ID}" | base64)\" | 
        .data.GITHUB__APP__CLIENT__ID = \"$(echo "${GITHUB__APP__CLIENT__ID}" | base64)\" |
        .data.GITHUB__APP__CLIENT__SECRET = \"$(echo "${GITHUB__APP__CLIENT__SECRET}" | base64)\" |
        .data.GITHUB__APP__WEBHOOK__URL = \"$(echo "${GITHUB__APP__WEBHOOK__URL}" | base64)\" |
        .data.GITHUB__APP__WEBHOOK__SECRET = \"$(echo "${GITHUB__APP__WEBHOOK__SECRET}" | base64)\" |
        .data.GITHUB__APP__PRIVATE_KEY = \"$(echo "${GITHUB__APP__PRIVATE_KEY}" | base64)\""  -M -I=0 -o=json)
    echo -n "."
fi
if [[ $RHDH_GITLAB_INTEGRATION == "true" ]]; then
    EXTRA_ENV_SECRET_PATCH=$(echo "$EXTRA_ENV_SECRET_PATCH" | yq \
        ".data.GITLAB__APP__CLIENT__ID = \"$(echo "${GITLAB__APP__CLIENT__ID}" | base64)\" |
        .data.GITLAB__APP__CLIENT__SECRET = \"$(echo "${GITLAB__APP__CLIENT__SECRET}" | base64)\" |
        .data.GITLAB__TOKEN = \"$(echo "${GITLAB__TOKEN}" | base64)\""  -M -I=0 -o=json)
    echo -n "."
fi
if [ ! -z "${QUAY__API_TOKEN}" ]; then
    EXTRA_ENV_SECRET_PATCH=$(echo "$EXTRA_ENV_SECRET_PATCH" | yq \
        ".data.QUAY__API_TOKEN = \"$(echo "${QUAY__API_TOKEN}" | base64)\""  -M -I=0 -o=json)
    echo -n "."
fi
if [ ! -z "${LIGHTSPEED_API_TOKEN}" ]; then
    EXTRA_ENV_SECRET_PATCH=$(echo "$EXTRA_ENV_SECRET_PATCH" | yq \
        ".data.LIGHTSPEED_API_TOKEN = \"$(echo "${LIGHTSPEED_API_TOKEN}" | base64)\""  -M -I=0 -o=json)
    echo -n "."
fi
if [ -z "${RHDH_EXTRA_ENV_SECRET}" ]; then
    kubectl create secret generic $EXTRA_ENV_SECRET -n $NAMESPACE
    if [ $? -ne 0 ]; then
        echo "FAIL"
        exit 1
    fi
    echo -n "."
elif [ -z "$(kubectl -n $NAMESPACE get secret $RHDH_EXTRA_ENV_SECRET -o name --ignore-not-found)" ]; then
    if [ $? -ne 0 ]; then
        echo "FAIL"
        exit 1
    fi
    echo -n "Extra environment variable secret '${RHDH_EXTRA_ENV_SECRET}' not found!"
    echo "FAIL"
    exit 1
fi
kubectl patch secret ${RHDH_EXTRA_ENV_SECRET:-$EXTRA_ENV_SECRET} -n $NAMESPACE \
    --type 'merge' \
    -p="$EXTRA_ENV_SECRET_PATCH" >/dev/null
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi
echo "OK"

# Creating up app config
# Creates and sets up the extra app config to be applied to the developer hub instance
echo -n "* Creating up app config: "
EXTRA_APPCONFIG="$(cat $BASE_DIR/resources/developer-hub-app-config.yaml | yq '.data["app-config.extra.yaml"]' -M)"
echo -n "."
if [ -f $CATALOGS_FILE ] && [ "$(yq '.catalogs' $CATALOGS_FILE)" != "null" ]; then
    CATALOG_LOCATIONS=$(yq '.catalogs | map({"type": "url", "target": .})' $CATALOGS_FILE -M -I=0 -o=json)
    EXTRA_APPCONFIG=$(echo "$EXTRA_APPCONFIG" | yq ".catalog.locations = ${CATALOG_LOCATIONS}" -M -)
    echo -n "."
fi
if [[ $RHDH_GITHUB_INTEGRATION == "true" ]]; then
    EXTRA_APPCONFIG=$(echo "$EXTRA_APPCONFIG" | yq ".auth.providers.github.production.clientId = \"\${GITHUB__APP__CLIENT__ID}\" |
        .auth.providers.github.production.clientSecret = \"\${GITHUB__APP__CLIENT__SECRET}\" |
        .integrations.github[0].host = \"github.com\" |
        .integrations.github[0].apps[0].appId = \"\${GITHUB__APP__ID}\" |
        .integrations.github[0].apps[0].clientId = \"\${GITHUB__APP__CLIENT__ID}\" |
        .integrations.github[0].apps[0].clientSecret = \"\${GITHUB__APP__CLIENT__SECRET}\" |
        .integrations.github[0].apps[0].webhookUrl = \"\${GITHUB__APP__WEBHOOK__URL}\" |
        .integrations.github[0].apps[0].webhookSecret = \"\${GITHUB__APP__WEBHOOK__SECRET}\" |
        .integrations.github[0].apps[0].privateKey = \"\${GITHUB__APP__PRIVATE_KEY}\"" -M -)
    echo -n "."
fi
if [[ $RHDH_GITLAB_INTEGRATION == "true" ]]; then
    EXTRA_APPCONFIG=$(echo "$EXTRA_APPCONFIG" | yq ".auth.providers.gitlab.production.clientId = \"\${GITLAB__APP__CLIENT__ID}\" |
        .auth.providers.gitlab.production.clientSecret = \"\${GITLAB__APP__CLIENT__SECRET}\" |
        .integrations.gitlab[0].host = \"gitlab.com\" |
        .integrations.gitlab[0].token = \"\${GITLAB__TOKEN}\"" -M -)
    echo -n "."
fi
if [ ! -z "${QUAY__API_TOKEN}" ]; then
    EXTRA_APPCONFIG=$(echo "$EXTRA_APPCONFIG" | yq ".proxy.endpoints./quay/api.headers.Authorization = \"Bearer \${QUAY__API_TOKEN}\"" -M -)
    echo -n "."
fi
if [ ! -z "${LIGHTSPEED_MODEL_URL}" ]; then
    EXTRA_APPCONFIG=$(echo "$EXTRA_APPCONFIG" | yq ".proxy.endpoints./lightspeed/api.target = \"${LIGHTSPEED_MODEL_URL}\"" -M -)

    if [ ! -z "${LIGHTSPEED_API_TOKEN}" ]; then
        EXTRA_APPCONFIG=$(echo "$EXTRA_APPCONFIG" | yq ".proxy.endpoints./lightspeed/api.headers.Authorization = \"Bearer \${LIGHTSPEED_API_TOKEN}\"" -M -)
    fi
    echo -n "."
fi
EXTRA_APPCONFIG=$EXTRA_APPCONFIG yq ".data[\"app-config.extra.yaml\"] = strenv(EXTRA_APPCONFIG)" $BASE_DIR/resources/developer-hub-app-config.yaml | \
    kubectl -n $NAMESPACE apply -f - >/dev/null
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi
echo "OK"

# Setting app config to instance
# Sets up the extra app config to the target developer hub instance
echo -n "* Setting app config to instance: "
if [[ $RHDH_INSTANCE_PROVIDED == "true" ]]; then
    kubectl get deploy $RHDH_DEPLOYMENT -n $NAMESPACE -o yaml | \
        yq '.spec.template.spec.volumes += {"name": "developer-hub-app-config", "configMap": {"name": "developer-hub-app-config", "defaultMode": 420, "optional": false}} | 
        .spec.template.spec.containers[0].volumeMounts += {"name": "developer-hub-app-config", "readOnly": true, "mountPath": "/opt/app-root/src/app-config.extra.yaml", "subPath": "app-config.extra.yaml"} |
        .spec.template.spec.containers[0].args += ["--config", "/opt/app-root/src/app-config.extra.yaml"]' | \
        kubectl apply -f - >/dev/null
else
    kubectl -n $NAMESPACE get backstage $BACKSTAGE_CR_NAME -o yaml | \
        yq '.spec.application.appConfig.configMaps += [{"name": "developer-hub-app-config"}] | 
            .spec.application.appConfig.configMaps |= unique_by(.name)' -M -I=0 -o=json | \
        kubectl apply -n $NAMESPACE -f - >/dev/null
fi
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi
echo "OK"

# Include plugins
# Patches dynamic plugins ConfigMap with lists from each plugins file
if [ -z "$(kubectl -n $NAMESPACE get configmap $RHDH_PLUGINS_CONFIGMAP -o name --ignore-not-found)" ]; then
    echo -n "Plugins configmap '${RHDH_PLUGINS_CONFIGMAP}' not found!"
    echo "FAIL"
    exit 1
fi

plugins=$BASE_DIR/dynamic-plugins/*.yaml
if [ ! -z "${LIGHTSPEED_MODEL_URL}" ]; then
    plugins="$plugins $BASE_DIR/optional-plugins/lightspeed-plugins.yaml"
fi
for f in $plugins; do
    echo -n "* Patching in $(basename $f .yaml) plugins: "
    # Grab configmap and parse out the defined yaml file inside of its data to a temp file
    kubectl get configmap $RHDH_PLUGINS_CONFIGMAP -n $NAMESPACE -o yaml | yq '.data["dynamic-plugins.yaml"]' > temp-dynamic-plugins.yaml
    if [ $? -ne 0 ]; then
        echo "FAIL"
        exit 1
    fi

    # Edit the temp file to include the plugins
    yq -i ".plugins += $(yq '.plugins' $f -M -o json) | .plugins |= unique_by(.package)" temp-dynamic-plugins.yaml
    if [ $? -ne 0 ]; then
        echo "FAIL"
        exit 1
    fi

    # Patch the configmap that is deployed to update the defined yaml inside of it
    kubectl patch configmap $RHDH_PLUGINS_CONFIGMAP -n $NAMESPACE \
    --type='merge' \
    -p="{\"data\":{\"dynamic-plugins.yaml\":\"$(echo "$(cat temp-dynamic-plugins.yaml)" | sed 's/"/\\"/g' | sed 's/$/\\n/g' | tr -d '\n')\"}}"
    if [ $? -ne 0 ]; then
        echo "FAIL"
        exit 1
    fi

    # Cleanup temp files
    rm temp-dynamic-plugins.yaml

    echo "OK"
done

# Update existing RHDH deployment
if [[ $RHDH_INSTANCE_PROVIDED == "true" ]]; then
    echo -n "* Updating existing RHDH deployment"
    kubectl get deploy $RHDH_DEPLOYMENT -n $NAMESPACE -o yaml | \
        yq ".spec.template.spec.containers[0].envFrom += [{\"secretRef\": {\"name\": \"${RHDH_EXTRA_ENV_SECRET:-$EXTRA_ENV_SECRET}\"}}] |
        .spec.template.spec.containers[0].envFrom |= unique_by(.secretRef.name)" | \
        kubectl apply -f - >/dev/null
    if [ $? -ne 0 ]; then
        echo "FAIL"
        exit 1
    fi
    echo "OK"
fi

# Add Tekton information and plugin to backstage deployment data
echo -n "* Adding Tekton information and plugin to backstage deployment data: "
K8S_SA_SECRET_NAME=$(kubectl get secrets -n "$NAMESPACE" -o name | grep rhdh-kubernetes-plugin-token- | cut -d/ -f2 | head -1)
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi
if [[ $RHDH_INSTANCE_PROVIDED == "true" ]]; then
    kubectl get deploy $RHDH_DEPLOYMENT -n $NAMESPACE -o yaml | \
        yq ".spec.template.spec.containers[0].env += {\"name\": \"K8S_SA_TOKEN\", \"valueFrom\": {\"secretKeyRef\": {\"name\": \"${K8S_SA_SECRET_NAME}\", \"key\": \"token\"}}} | 
        .spec.template.spec.containers[0].env |= unique_by(.name)" | \
        kubectl apply -f - >/dev/null
else
    K8S_SA_TOKEN=$(kubectl -n $NAMESPACE get secret $K8S_SA_SECRET_NAME -o yaml | yq '.data.token' -M -I=0)
    
    kubectl -n $NAMESPACE get secret $RHDH_EXTRA_ENV_SECRET -o yaml | yq ".data.K8S_SA_TOKEN = \"${K8S_SA_TOKEN}\"" -M -I=0 | \
        kubectl apply -n $NAMESPACE -f - >/dev/null
fi
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi
echo "OK"

# Add ArgoCD information to backstage deployment data
echo -n "* Adding ArgoCD information to backstage deployment data: "
if [ -z "$(kubectl -n $NAMESPACE get configmap "argocd-config" -o name --ignore-not-found)" ]; then
    echo -n "ArgoCD config 'argocd-config' not found!"
    echo "FAIL"
    exit 1
fi
if [ -z "$(kubectl -n $NAMESPACE get secret "rhdh-argocd-secret" -o name --ignore-not-found)" ]; then
    echo -n "ArgoCD secret 'rhdh-argocd-secret' not found!"
    echo "FAIL"
    exit 1
fi
if [[ $RHDH_INSTANCE_PROVIDED == "true" ]]; then
    # Add ArgoCD instance information and plugin to backstage deployment data
    kubectl get deploy $RHDH_DEPLOYMENT -n $NAMESPACE -o yaml | \
        yq '.spec.template.spec.volumes += [{"name": "argocd-config", "configMap": {"name": "argocd-config", "defaultMode": 420, "optional": false}}] |
        .spec.template.spec.containers[0].envFrom += [{"secretRef": {"name": "rhdh-argocd-secret"}}] |
        .spec.template.spec.containers[0].volumeMounts += [{"name": "argocd-config", "readOnly": true, "mountPath": "/opt/app-root/src/argocd-config.yaml", "subPath": "argocd-config.yaml"}] |
        .spec.template.spec.containers[0].args += ["--config", "/opt/app-root/src/argocd-config.yaml"]' | \
        kubectl apply -f - >/dev/null
else
    kubectl -n $NAMESPACE get backstage $BACKSTAGE_CR_NAME -o yaml | \
        yq '.spec.application.appConfig.configMaps += [{"name": "argocd-config"}] | 
            .spec.application.appConfig.configMaps |= unique_by(.name) |
            .spec.application.extraEnvs.secrets += [{"name": "rhdh-argocd-secret"}] | 
            .spec.application.extraEnvs.secrets |= unique_by(.name)' -M -I=0 -o=json | \
        kubectl apply -n $NAMESPACE -f - >/dev/null
fi
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi
echo "OK"
