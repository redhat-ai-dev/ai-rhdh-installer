#!/bin/bash

# Constants
BACKSTAGE_CR_NAME="ai-rh-developer-hub"
DEFAULT_RHDH_DEPLOYMENT="backstage-ai-rh-developer-hub" # deployment created by rhdh operator by default
PLUGIN_CONFIGMAP="backstage-dynamic-plugins-ai-rh-developer-hub" # configmap created by rhdh operator for plugins by default
EXTRA_ENV_SECRET="ai-rh-developer-hub-env" # secret created by rhdh installer to store private env vars

# Variables
BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))/.."
CATALOGS_FILE=${CATALOGS_FILE:-"${BASE_DIR}/catalogs.yaml"}
RHDH_DEPLOYMENT="${DEFAULT_RHDH_DEPLOYMENT}"
RHDH_EXTRA_ENV_SECRET="${EXTRA_ENV_SECRET}"
RHDH_PLUGINS_CONFIGMAP="${PLUGIN_CONFIGMAP}"
NAMESPACE=${NAMESPACE:-"ai-rhdh"}
EXISTING_NAMESPACE=${EXISTING_NAMESPACE:-''}
EXISTING_DEPLOYMENT=${EXISTING_DEPLOYMENT:-''}
EXISTING_EXTRA_ENV_SECRET=${EXISTING_EXTRA_ENV_SECRET:-''}
RHDH_PLUGINS=${RHDH_PLUGINS:-''}
RHDH_INSTANCE_PROVIDED=${RHDH_INSTANCE_PROVIDED:-false}
RHDH_GITHUB_INTEGRATION=${RHDH_GITHUB_INTEGRATION:-false}
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

    # Reads GitHub Org App Webhook URL
    until [ ! -z "${GITHUB__APP__WEBHOOK__URL}" ]; do
        read -p "Enter your GitHub App Webhook URL: " GITHUB__APP__WEBHOOK__URL
        if [ -z "${GITHUB__APP__WEBHOOK__URL}" ]; then
            echo "No GitHub App Webhook URL entered, try again."
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
kubectl patch secret $RHDH_EXTRA_ENV_SECRET -n $NAMESPACE \
    --type 'merge' \
    -p="$EXTRA_ENV_SECRET_PATCH" >/dev/null
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
EXTRA_APPCONFIG=$EXTRA_APPCONFIG yq ".data[\"app-config.extra.yaml\"] = strenv(EXTRA_APPCONFIG)" $BASE_DIR/resources/developer-hub-app-config.yaml | \
    kubectl -n $NAMESPACE apply -f - >/dev/null
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
echo "OK"