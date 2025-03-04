#!/bin/bash

# Constants
BACKSTAGE_CR_NAME="ai-rh-developer-hub"
DEFAULT_RHDH_DEPLOYMENT="backstage-ai-rh-developer-hub" # deployment created by rhdh operator by default
PLUGIN_CONFIGMAP="dynamic-plugins" # configmap created by rhdh operator for plugins by default
EXTRA_ENV_SECRET="extra-env" # secret created by rhdh installer to store private env vars
CATALOG_GITHUB_SCHEDULE_FREQUENCY_MINUTES="30"
CATALOG_GITHUB_SCHEDULE_INITIALDELAY_SECONDS="15"
CATALOG_GITHUB_SCHEDULE_TIMEOUT_MINUTES="15"
CATALOG_GITLAB_SCHEDULE_FREQUENCY_MINUTES="30"
CATALOG_GITLAB_SCHEDULE_INITIALDELAY_SECONDS="15"
CATALOG_GITLAB_SCHEDULE_TIMEOUT_MINUTES="15"

# Variables
BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))/.."
INCLUDES_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))/includes"
CATALOGS_FILE=${CATALOGS_FILE:-"${BASE_DIR}/catalogs.yaml"}
RHDH_DEPLOYMENT="${DEFAULT_RHDH_DEPLOYMENT}"
RHDH_EXTRA_ENV_SECRET="${RHDH_DEPLOYMENT}-${EXTRA_ENV_SECRET}"
RHDH_PLUGINS_CONFIGMAP="${RHDH_DEPLOYMENT}-${PLUGIN_CONFIGMAP}"
NAMESPACE=${NAMESPACE:-"ai-rhdh"}
PIPELINES_NAMESPACE=${PIPELINES_NAMESPACE:-"openshift-pipelines"}
EXISTING_NAMESPACE=${EXISTING_NAMESPACE:-''}
EXISTING_DEPLOYMENT=${EXISTING_DEPLOYMENT:-''}
EXISTING_EXTRA_ENV_SECRET=${EXISTING_EXTRA_ENV_SECRET:-''}
RHDH_PLUGINS=${RHDH_PLUGINS:-''}
RHDH_INSTANCE_PROVIDED=${RHDH_INSTANCE_PROVIDED:-false}
RHDH_GITHUB_INTEGRATION=${RHDH_GITHUB_INTEGRATION:-true}
RHDH_GITLAB_INTEGRATION=${RHDH_GITLAB_INTEGRATION:-false}
RHDH_SIGNIN_PROVIDER=${RHDH_SIGNIN_PROVIDER:-''}

# Secret variables
GITHUB__APP__ID=${GITHUB__APP__ID:-''}
GITHUB__APP__CLIENT__ID=${GITHUB__APP__CLIENT__ID:-''}
GITHUB__APP__CLIENT__SECRET=${GITHUB__APP__CLIENT__SECRET:-''}
GITHUB__APP__WEBHOOK__URL=${GITHUB__APP__WEBHOOK__URL:-''}
GITHUB__APP__WEBHOOK__SECRET=${GITHUB__APP__WEBHOOK__SECRET:-''}
GITHUB__APP__PRIVATE_KEY=${GITHUB__APP__PRIVATE_KEY:-''}
GITHUB__HOST=${GITHUB__HOST:-'github.com'}
GITHUB__ORG__NAME=${GITHUB__ORG__NAME:-''}
GITOPS__GIT_TOKEN=${GITOPS__GIT_TOKEN:-''}
GITLAB__APP__CLIENT__ID=${GITLAB__APP__CLIENT__ID:-''}
GITLAB__APP__CLIENT__SECRET=${GITLAB__APP__CLIENT__SECRET:-''}
GITLAB__TOKEN=${GITLAB__TOKEN:-''}
GITLAB__HOST=${GITLAB__HOST:-'gitlab.com'}
GITLAB__GROUP__NAME=${GITLAB__GROUP__NAME:-''}
GITLAB__ORG__ENABLED=${GITLAB__ORG__ENABLED:-''}
QUAY__DOCKERCONFIGJSON=${QUAY__DOCKERCONFIGJSON:-''}
QUAY__API_TOKEN=${QUAY__API_TOKEN:-''}
LIGHTSPEED_MODEL_URL=${LIGHTSPEED_MODEL_URL:-''}
LIGHTSPEED_API_TOKEN=${LIGHTSPEED_API_TOKEN:-''}
KUBERNETES_SA=${KUBERNETES_SA:-'rhdh-kubernetes-plugin'}
KUBERNETES_SA_TOKEN_SECRET=${KUBERNETES_SA_TOKEN_SECRET:-'rhdh-kubernetes-plugin-token'}

signin_provider=''

# Includes
. ${INCLUDES_DIR}/webhooks # Include fetch function for getting webhook url
. ${INCLUDES_DIR}/installer-resources # Getter functions for installer resources
. ${INCLUDES_DIR}/configure-envs # Extra environment variable secret functions
. ${INCLUDES_DIR}/configure-appconfig # AppConfig configmap functions
. ${INCLUDES_DIR}/configure-plugins # Dynamic plugins configmap functions

configure_dh() {
    # Use existing variables if RHDH instance is provided
    if [[ $RHDH_INSTANCE_PROVIDED != "true" ]] && [[ $RHDH_INSTANCE_PROVIDED != "false" ]]; then
        echo "[FAIL] RHDH_INSTANCE_PROVIDED needs to be set to either 'true' or 'false'"
        return 1
    elif [[ $RHDH_INSTANCE_PROVIDED == "true" ]]; then
        NAMESPACE="${EXISTING_NAMESPACE}"
        RHDH_DEPLOYMENT="${EXISTING_DEPLOYMENT}"

        # If existing extra env Secret is provided then use provided name else regen default name
        if [ -z "${EXISTING_EXTRA_ENV_SECRET}" ]; then
            RHDH_EXTRA_ENV_SECRET="${RHDH_DEPLOYMENT}-${EXTRA_ENV_SECRET}-$(openssl rand -hex 6)"
        else
            RHDH_EXTRA_ENV_SECRET="${EXISTING_EXTRA_ENV_SECRET}"
        fi

        # If existing dynamic plugins ConfigMap is provided then use provided name else regen default name
        if [ -z "${RHDH_PLUGINS}" ]; then
            RHDH_PLUGINS_CONFIGMAP="${RHDH_DEPLOYMENT}-${PLUGIN_CONFIGMAP}-$(openssl rand -hex 6)"
        else
            RHDH_PLUGINS_CONFIGMAP="${RHDH_PLUGINS}"
        fi
    fi

    # Reading secrets
    # Reads secrets either from environment variables or user input
    echo -n "* Reading secrets: "

    # Reads GitHub secrets if enabling GitHub integration
    if [[ $RHDH_GITHUB_INTEGRATION == "true" ]]; then
        signin_provider='github'

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

        # Reads GitHub Org Name
        until [ ! -z "${GITHUB__ORG__NAME}" ]; do
            read -p "Enter your GitHub Org Name: " GITHUB__ORG__NAME
            if [ -z "${GITHUB__ORG__NAME}" ]; then
                echo "No GitHub Org Name entered, try again."
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

        # Reads GitLab Group Name
        until [ ! -z "${GITLAB__GROUP__NAME}" ]; do
            read -p "Enter your GitLab Group Name: " GITLAB__GROUP__NAME
            if [ -z "${GITLAB__GROUP__NAME}" ]; then
                echo "No GitLab Group Name entered, try again."
            fi
        done

        # Reads GitLab Org Enabled
        if [ -z "${GITLAB__ORG__ENABLED}" ] && [[ $GITLAB__HOST == "gitlab.com" ]]
        then
            GITLAB__ORG__ENABLED='true' # required for gitlab.com, see https://backstage.io/docs/integrations/gitlab/org#users
        elif [ -z "${GITLAB__ORG__ENABLED}" ]
        then
            prompt=''
            until [[ "${GITLAB__ORG__ENABLED}" == "true" ]] || [[ "${GITLAB__ORG__ENABLED}" == "false" ]]; do
                read -p "Is GitLab Organizations enabled? (y/n): " prompt

                case "$prompt" in
                    y)
                        GITLAB__ORG__ENABLED='true';;
                    n)
                        GITLAB__ORG__ENABLED='false';;
                    *)
                        echo 'Please enter "y" or "n", try again.';;
                esac
            done
        fi

        # Choose which sign in provider to use
        if [[ $RHDH_GITHUB_INTEGRATION == "true" ]] && [[ ! $RHDH_SIGNIN_PROVIDER =~ ^(github|gitlab)$ ]]; then
            echo "Multiple authentication providers detected"
            PS3='Select the desired sign in method (type in number or name): '
            options=("github" "gitlab")
            select opt in "${options[@]}"
            do
                if [[ -n $opt ]]; then
                    signin_provider=$opt
                    break
                elif [[ "${options[*]}" == *"$REPLY"* ]]; then
                    signin_provider=$REPLY
                    break
                fi
            done
        fi
    fi

    if [[ ! $RHDH_SIGNIN_PROVIDER =~ ^(github|gitlab)$ ]]; then 
        RHDH_SIGNIN_PROVIDER="${signin_provider}"
    fi

    # Reads Quay API Token
    # Optional: If an API Token is not entered, there will be none provided to the developer hub app config
    if [[ ! $BYPASS_OPTIONAL_INPUT =~ ",QUAY__API_TOKEN" ]] && [ -z "${QUAY__API_TOKEN}" ]; then
        read -p "Enter your Quay API Token (Optional): " QUAY__API_TOKEN
    fi

    echo "OK"

    # Reads secrets for lightspeed plugin if enabling lightspeed integration
    if [[ ${LIGHTSPEED_INTEGRATION} == "true" ]]; then
        # Reads lightspeed model endpoint URL
        until [ ! -z "${LIGHTSPEED_MODEL_URL}" ]; do
            read -p "Enter your model URL for lightspeed: " LIGHTSPEED_MODEL_URL
            if [ -z "${LIGHTSPEED_MODEL_URL}" ]; then
                echo "No model URL for lightspeed entered, try again."
            fi
        done
        
        # Reads API token for lightspeed plugin
        # Optional: If no token is entered, lightspeed plugin will not use authenticated communication
        if [[ ! $BYPASS_OPTIONAL_INPUT =~ ",LIGHTSPEED_API_TOKEN" ]] && [ -z "${LIGHTSPEED_API_TOKEN}" ]; then
            read -p "Enter API token for lightspeed (Optional): " LIGHTSPEED_API_TOKEN
        fi

        # Make sure the target url ends in /v1
        if ! [[ $LIGHTSPEED_MODEL_URL =~ \/v1$ ]]; then
            LIGHTSPEED_MODEL_URL="$LIGHTSPEED_MODEL_URL/v1"
        fi

        # Keep the plugin checksum up to date with the latest release
        plugin_sha=$(npm view @janus-idp/backstage-plugin-lightspeed dist.integrity)
        yq -i ".plugins.[0].integrity = \"${plugin_sha}\"" $BASE_DIR/optional-plugins/lightspeed-plugins.yaml
    fi

    echo "OK"

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
        return 1
    fi
    echo "OK"

    # Fetching Webhook URL
    if [[ $RHDH_GITHUB_INTEGRATION == "true" ]]; then
        echo -n "* Fetching Webhook URL: "
        if [ -z "${GITHUB__APP__WEBHOOK__URL}" ]; then
            GITHUB__APP__WEBHOOK__URL="$(fetch_gh_webhook "${PIPELINES_NAMESPACE}" "${NAMESPACE}" "${RHDH_EXTRA_ENV_SECRET}")"
            if [ $? -ne 0 ]; then
                echo "FAIL"
                return 1
            fi
        fi
        echo "OK"
    fi

    # Patching extra env secret
    # Patches extra env var secret to include private vars passed into this script 
    # and referenced by the extra app config
    echo -n "* Building extra env secret: "
    EXTRA_ENV_SECRET_PATCH=''
    if [[ $RHDH_GITHUB_INTEGRATION == "true" ]]; then
        EXTRA_ENV_SECRET_PATCH="$(build_gh_envs_secret_data)"
        echo -n "."
    fi
    if [[ $RHDH_GITLAB_INTEGRATION == "true" ]]; then
        EXTRA_ENV_SECRET_PATCH="$(build_gl_envs_secret_data "${EXTRA_ENV_SECRET_PATCH}")"
        echo -n "."
    fi
    if [ ! -z "${QUAY__API_TOKEN}" ]; then
        EXTRA_ENV_SECRET_PATCH="$(build_quay_envs_secret_data "${EXTRA_ENV_SECRET_PATCH}")"
        echo -n "."
    fi
    if [ ! -z "${LIGHTSPEED_API_TOKEN}" ]; then
        EXTRA_ENV_SECRET_PATCH="$(build_ls_envs_secret_data "${EXTRA_ENV_SECRET_PATCH}")"
        echo -n "."
    fi

    if [[ "$(is_extra_envs_patch "${EXISTING_EXTRA_ENV_SECRET}" "${RHDH_DEPLOYMENT}" "${NAMESPACE}")" == "true" ]]; then
        if [ -z "${EXISTING_EXTRA_ENV_SECRET}" ]; then RHDH_EXTRA_ENV_SECRET="$(get_extra_envs_secret "${RHDH_DEPLOYMENT}" "${NAMESPACE}")"; fi
        kubectl patch secret ${RHDH_EXTRA_ENV_SECRET} -n $NAMESPACE \
        --type 'merge' \
        -p="$EXTRA_ENV_SECRET_PATCH" >/dev/null
    else
        RHDH_EXTRA_ENV_SECRET="${RHDH_EXTRA_ENV_SECRET}-$(openssl rand -hex 6)"
        create_extra_env_secret "${RHDH_EXTRA_ENV_SECRET}" "${RHDH_DEPLOYMENT}" "${NAMESPACE}" "${EXTRA_ENV_SECRET_PATCH}" >/dev/null
    fi
    if [ $? -ne 0 ]; then
        echo "FAIL"
        return 1
    fi
    echo "OK"

    # Creating up app config
    # Creates and sets up the extra app config to be applied to the developer hub instance
    echo -n "* Creating up app config: "
    EXTRA_APPCONFIG="$(cat $BASE_DIR/resources/developer-hub-app-config.yaml | yq '.data["app-config.extra.yaml"]' -M)"
    echo -n "."
    if [ -f $CATALOGS_FILE ] && [ "$(yq '.catalogs' $CATALOGS_FILE)" != "null" ]; then
        EXTRA_APPCONFIG=$(build_catalog_appconfig "${CATALOGS_FILE}" "${EXTRA_APPCONFIG}")
        echo -n "."
    fi
    if [[ $RHDH_GITHUB_INTEGRATION == "true" ]]; then
        EXTRA_APPCONFIG=$(build_gh_appconfig "${EXTRA_APPCONFIG}")
        echo -n "."
    fi
    if [[ $RHDH_GITLAB_INTEGRATION == "true" ]]; then
        EXTRA_APPCONFIG=$(build_gl_appconfig "${EXTRA_APPCONFIG}")
        echo -n "."
    fi
    if [ ! -z "${RHDH_SIGNIN_PROVIDER}" ]; then
        EXTRA_APPCONFIG=$(build_signin_appconfig "${EXTRA_APPCONFIG}")
        echo -n "."
    fi
    if [ ! -z "${QUAY__API_TOKEN}" ]; then
        EXTRA_APPCONFIG=$(build_quay_appconfig "${EXTRA_APPCONFIG}")
        echo -n "."
    fi
    if [[ $LIGHTSPEED_INTEGRATION == "true" ]]; then
        if [ ! -z "${LIGHTSPEED_API_TOKEN}" ]; then
            EXTRA_APPCONFIG=$(build_ls_appconfig "${EXTRA_APPCONFIG}" --token)
        else
            EXTRA_APPCONFIG=$(build_ls_appconfig "${EXTRA_APPCONFIG}")
        fi
        echo -n "."
    fi
    create_appconfig "${NAMESPACE}" "${EXTRA_APPCONFIG}"
    if [ $? -ne 0 ]; then
        echo "FAIL"
        return 1
    fi
    echo "OK"

    # Setting app config to instance
    # Sets up the extra app config to the target developer hub instance
    echo -n "* Setting app config to instance: "
    if [[ $RHDH_INSTANCE_PROVIDED == "true" ]]; then
        attach_appconfig_to_deployment "developer-hub-app-config" "${RHDH_DEPLOYMENT}" "${NAMESPACE}"
    else
        attach_appconfig_to_cr "developer-hub-app-config" "${BACKSTAGE_CR_NAME}" "${NAMESPACE}"
    fi
    if [ $? -ne 0 ]; then
        echo "FAIL"
        return 1
    fi
    echo "OK"

    # Include plugins
    # Creates dynamic plugins ConfigMap if does not exist
    if [[ "$(is_plugins_patch "${RHDH_PLUGINS}" "${RHDH_DEPLOYMENT}" "${NAMESPACE}")" == "false" ]]; then
        echo -n "* Creating dynamic plugins ConfigMap: "
        RHDH_PLUGINS_CONFIGMAP="${RHDH_PLUGINS_CONFIGMAP}-$(openssl rand -hex 6)"
        create_plugins "${RHDH_PLUGINS_CONFIGMAP}" "${RHDH_DEPLOYMENT}" "${NAMESPACE}"
        if [ $? -ne 0 ]; then
            echo "FAIL"
            return 1
        fi
        echo "OK"
    elif [ -z "${RHDH_PLUGINS}" ]; then
        RHDH_PLUGINS_CONFIGMAP="$(get_plugins_configmap "${RHDH_DEPLOYMENT}" "${NAMESPACE}")"
    fi

    # Dynamic Plugins ConfigMap should exist now
    if [ -z "$(kubectl -n $NAMESPACE get configmap $RHDH_PLUGINS_CONFIGMAP -o name --ignore-not-found)" ]; then
        echo "[FAIL] Plugins configmap '${RHDH_PLUGINS_CONFIGMAP}' not found!"
        return 1
    fi

    # Patches dynamic plugins ConfigMap with lists from each plugins file
    plugins=$BASE_DIR/dynamic-plugins/*.yaml
    if [[ $LIGHTSPEED_INTEGRATION == "true" ]]; then
        plugins="$plugins $BASE_DIR/optional-plugins/lightspeed-plugins.yaml"
    fi
    for f in $plugins; do
        echo -n "* Patching in $(basename $f .yaml) plugins: "
        patch_plugins "${f}" "${RHDH_PLUGINS_CONFIGMAP}" "${NAMESPACE}"
        if [ $? -ne 0 ]; then
            echo "FAIL"
            return 1
        fi
        echo "OK"
    done

    # Adds dynamic plugins ConfigMap to RHDH deployment if not added
    if [[ "$(is_plugins_attached "${RHDH_PLUGINS_CONFIGMAP}" "${RHDH_DEPLOYMENT}" "${NAMESPACE}")" == "false" ]]; then
        echo -n "* Adding dynamic plugins ConfigMap to RHDH deployment: "
        if [[ $RHDH_INSTANCE_PROVIDED == "true" ]]; then
            attach_plugins_to_deployment "${RHDH_PLUGINS_CONFIGMAP}" "${RHDH_DEPLOYMENT}" "${NAMESPACE}"
        else
            attach_plugins_to_cr "${RHDH_PLUGINS_CONFIGMAP}" "${BACKSTAGE_CR_NAME}" "${NAMESPACE}"
        fi
        if [ $? -ne 0 ]; then
            echo "FAIL"
            return 1
        fi
        echo "OK"
    fi

    # Adds extra env secret to RHDH deployment
    if [ -z "$(kubectl -n $NAMESPACE get secret $RHDH_EXTRA_ENV_SECRET -o name --ignore-not-found)" ]; then
        echo "[FAIL] Extra env secret '${RHDH_EXTRA_ENV_SECRET}' not found!"
        return 1
    fi
    if [[ "$(is_extra_envs_attached "${RHDH_EXTRA_ENV_SECRET}" "${RHDH_DEPLOYMENT}" "${NAMESPACE}")" == "false" ]]; then
        echo -n "* Adding extra env secret to RHDH deployment: "
        if [[ $RHDH_INSTANCE_PROVIDED == "true" ]]; then
            attach_extra_envs_to_deployment "${RHDH_EXTRA_ENV_SECRET}" "${RHDH_DEPLOYMENT}" "${NAMESPACE}"
        else
            attach_extra_envs_to_cr "${RHDH_EXTRA_ENV_SECRET}" "${BACKSTAGE_CR_NAME}" "${NAMESPACE}"
        fi
        if [ $? -ne 0 ]; then
            echo "FAIL"
            return 1
        fi
        echo "OK"
    fi

    # Add Tekton information and plugin to backstage deployment data
    echo -n "* Adding Tekton information and plugin to backstage deployment data: "
    K8S_SA_SECRET=$(kubectl get secrets -n "$NAMESPACE" -o name | grep "$KUBERNETES_SA_TOKEN_SECRET" | cut -d/ -f2 | head -1)
    if [ $? -ne 0 ]; then
        echo "FAIL"
        exit 1
    fi
    if [[ $RHDH_INSTANCE_PROVIDED == "true" ]]; then
        kubectl get deploy $RHDH_DEPLOYMENT -n $NAMESPACE -o yaml | \
            yq ".spec.template.spec.containers[0].env += {\"name\": \"K8S_SA_TOKEN\", \"valueFrom\": {\"secretKeyRef\": {\"name\": \"${K8S_SA_SECRET}\", \"key\": \"token\"}}} | 
            .spec.template.spec.containers[0].env += {\"name\": \"K8S_SA\", \"valueFrom\": {\"secretKeyRef\": {\"name\": \"${KUBERNETES_SA}\", \"key\": \"token\"}}} |
            .spec.template.spec.containers[0].env |= unique_by(.name)" | \
            kubectl apply -f - >/dev/null
    else
        K8S_SA_TOKEN=$(kubectl -n $NAMESPACE get secret $K8S_SA_SECRET -o yaml | yq '.data.token' -M -I=0)
        KUBERNETES_SA_ENCODED=$(echo -n "$KUBERNETES_SA" | base64 -w 0)
        kubectl -n $NAMESPACE get secret $RHDH_EXTRA_ENV_SECRET -o yaml | yq ".data.K8S_SA = \"${KUBERNETES_SA_ENCODED}\" | .data.K8S_SA_TOKEN = \"${K8S_SA_TOKEN}\"" -M -I=0 | \
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
        echo "[FAIL] ArgoCD config 'argocd-config' not found!"
        return 1
    fi
    if [ -z "$(kubectl -n $NAMESPACE get secret "rhdh-argocd-secret" -o name --ignore-not-found)" ]; then
        echo "[FAIL] ArgoCD secret 'rhdh-argocd-secret' not found!"
        return 1
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
        return 1
    fi
    echo "OK"

    return 0
}

# Configure Developer Hub
configure_dh
exit $?
