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

# Gets RHDH installer configured resource name by RHDH resource type, deployment name, and namespace
get_installer_resource() {
    local rhdh_resource=$1
    local deployment_name=$2
    local namespace=$3
    local filter=".metadata.annotations.\"rhdhpai.redhat.com/rhdh-installer-instance\" == \"${deployment_name}\" and .metadata.annotations.\"rhdhpai.redhat.com/rhdh-resource\" == \"${rhdh_resource}\""
    local resource_type
    local resource_name

    case "${rhdh_resource}" in
        extra-envs)
            resource_type='secret'
            ;;
        dynamic-plugins|appconfig)
            resource_type='configmap'
            ;;
        *)
            echo "unknown rhdh resource type '${rhdh_resource}'"
            return 1
            ;;
    esac

    resource_name="$(kubectl get ${resource_type} -n ${namespace} -o=json --ignore-not-found | yq ".items[] | select(${filter}) | .metadata.name" -M)"
    if [ -z "${resource_name}" ]; then
        echo "error: not found"
        return 1
    fi

    echo "${resource_name}"
    return 0
}

# Gets RHDH installer configured extra environment variable secret name by deployment name and namespace
get_extra_envs_secret() {
    local deployment_name=$1
    local namespace=$2
    
    get_installer_resource extra-envs $deployment_name $namespace
    return $?
}

# Gets RHDH installer configured dynamic plugins configmap name by deployment name and namespace
get_plugins_configmap() {
    local deployment_name=$1
    local namespace=$2
    
    get_installer_resource dynamic-plugins $deployment_name $namespace
    return $?
}

# Gets RHDH installer configured app config configmap name by deployment name and namespace
get_appconfig_configmap() {
    local deployment_name=$1
    local namespace=$2
    
    get_installer_resource app-config $deployment_name $namespace
    return $?
}

# Checks if extra envs resource exists
attached_extra_envs_exists() {
    local deployment_name=$1
    local namespace=$2
    
    get_extra_envs_secret $deployment_name $namespace > /dev/null
    if [ $? -eq 0 ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Checks if dynamic plugins resource exists
attached_plugins_exists() {
    local deployment_name=$1
    local namespace=$2
    
    get_plugins_configmap $deployment_name $namespace > /dev/null
    if [ $? -eq 0 ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Checks if app config resource exists
attached_appconfig_exists() {
    local deployment_name=$1
    local namespace=$2
    
    get_appconfig_configmap $deployment_name $namespace > /dev/null
    if [ $? -eq 0 ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Fetches GitHub webhook url
fetch_gh_webhook() {
    local pipelines_namespace="${1}"
    local namespace="${2}"
    local extra_env_secret="${3}"

    if [ -z "${extra_env_secret}" ]; then
        kubectl get routes -n "${pipelines_namespace}" pipelines-as-code-controller -o jsonpath="https://{.spec.host}"
    elif [ ! -z "$(kubectl get secret -n ${namespace} ${extra_env_secret} --ignore-not-found -o name)" ] && [[ "$(kubectl -n ${namespace} get secret ${extra_env_secret} -o yaml | yq '.data.GITHUB__APP__WEBHOOK__URL')" != "null" ]]; then
        if [ $? -ne 0 ]; then return 1; fi
        kubectl -n ${namespace} get secret ${extra_env_secret} -o yaml | yq '.data.GITHUB__APP__WEBHOOK__URL' | base64 -d
    else
        kubectl get routes -n "${pipelines_namespace}" pipelines-as-code-controller -o jsonpath="https://{.spec.host}"
    fi
}

# Returns true if the extra env secret should be patched and false if it should be created
is_extra_envs_patch() {
    local existing_extra_env_secret=$1
    local deployment_name=$2
    local namespace=$3
    local extra_env_secret_exists="$(attached_extra_envs_exists "${deployment_name}" "${namespace}")"
    
    if [[ "${extra_env_secret_exists}" == "true" ]] && [[ $RHDH_INSTANCE_PROVIDED != "true" ]]; then
        echo "true"
    elif [[ $RHDH_INSTANCE_PROVIDED == "true" ]] && [ ! -z "${existing_extra_env_secret}" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Builds extra envs secret data for GitHub integration
build_gh_envs_secret_data() {
    local env_secret_data="${1:-"$(yq -n -M -I=0 -o=json)"}"

    echo "$env_secret_data" | yq \
        ".data.GITHUB__APP__ID = \"$(echo "${GITHUB__APP__ID}" | base64)\" | 
        .data.GITHUB__APP__CLIENT__ID = \"$(echo "${GITHUB__APP__CLIENT__ID}" | base64)\" |
        .data.GITHUB__APP__CLIENT__SECRET = \"$(echo "${GITHUB__APP__CLIENT__SECRET}" | base64)\" |
        .data.GITHUB__APP__WEBHOOK__URL = \"$(echo "${GITHUB__APP__WEBHOOK__URL}" | base64)\" |
        .data.GITHUB__APP__WEBHOOK__SECRET = \"$(echo "${GITHUB__APP__WEBHOOK__SECRET}" | base64)\" |
        .data.GITHUB__APP__PRIVATE_KEY = \"$(echo "${GITHUB__APP__PRIVATE_KEY}" | base64)\" |
        .data.GITHUB__HOST = \"$(echo "${GITHUB__HOST}" | base64)\" |
        .data.GITHUB__ORG__NAME = \"$(echo "${GITHUB__ORG__NAME}" | base64)\""  -M -I=0 -o=json
}

# Builds extra envs secret data for GitLab integration
build_gl_envs_secret_data() {
    local env_secret_data="${1:-"$(yq -n -M -I=0 -o=json)"}"

    echo "$env_secret_data" | yq \
        ".data.GITLAB__APP__CLIENT__ID = \"$(echo "${GITLAB__APP__CLIENT__ID}" | base64)\" |
        .data.GITLAB__APP__CLIENT__SECRET = \"$(echo "${GITLAB__APP__CLIENT__SECRET}" | base64)\" |
        .data.GITLAB__TOKEN = \"$(echo "${GITLAB__TOKEN}" | base64)\" |
        .data.GITLAB__HOST = \"$(echo "${GITLAB__HOST}" | base64)\" |
        .data.GITLAB__GROUP__NAME = \"$(echo "${GITLAB__GROUP__NAME}" | base64)\" |
        .data.GITLAB__ORG__ENABLED = \"$(echo "${GITLAB__ORG__ENABLED}" | base64)\""  -M -I=0 -o=json
}

# Builds extra envs secret data for Quay integration
build_quay_envs_secret_data() {
    local env_secret_data="${1:-"$(yq -n -M -I=0 -o=json)"}"

    echo "$env_secret_data" | yq ".data.QUAY__API_TOKEN = \"$(echo "${QUAY__API_TOKEN}" | base64)\""  -M -I=0 -o=json        
}

# Builds extra envs secret data for LightSpeed integration
build_ls_envs_secret_data() {
    local env_secret_data="${1:-"$(yq -n -M -I=0 -o=json)"}"

    echo "$env_secret_data" | yq ".data.LIGHTSPEED_API_TOKEN = \"$(echo "${LIGHTSPEED_API_TOKEN}" | base64)\""  -M -I=0 -o=json
}

# Creates a secret to use to store the extra env vars for RHDH
create_extra_env_secret() {
    local extra_env_secret_name=$1
    local deployment_name=$2
    local namespace=$3
    local env_secret_data="${4:-"$(yq -n -M -I=0 -o=json)"}"

    if [[ $RHDH_INSTANCE_PROVIDED == "true" ]]; then
        yq ".metadata.name = \"${extra_env_secret_name}\" |
            .metadata.annotations.\"rhdhpai.redhat.com/rhdh-installer-instance\" = \"${deployment_name}\" |
            .data = $(yq '.data' <<< $env_secret_data)" \
            $BASE_DIR/resources/developer-hub-extra-env.yaml | kubectl -n $namespace apply -f -
    else
        yq ".metadata.name = \"${extra_env_secret_name}\" |
            .metadata.annotations.\"rhdhpai.redhat.com/rhdh-installer-instance\" = \"${deployment_name}\" |
            .metadata.annotations.\"rhdh.redhat.com/backstage-name\" = \"${BACKSTAGE_CR_NAME}\" |
            .data = $(yq '.data' <<< $env_secret_data)" \
            $BASE_DIR/resources/developer-hub-extra-env.yaml | kubectl -n $namespace apply -f -
    fi

    return $?
}

# Return true if there is an existing configured extra environment variable secret attached to the target RHDH deployment
is_extra_envs_attached() {
    local extra_envs_secret=$1
    local deployment_name=$2
    local namespace=$3
    local extra_envs="$(kubectl get deployment $deployment_name -n $namespace -o=jsonpath='{.spec.template.spec}' --ignore-not-found |
        yq ".containers[].envFrom[] | select(.secretRef.name == \"${extra_envs_secret}\") | .secretRef.name" -M)"
    local extra_env_secret_exists="$(attached_extra_envs_exists "${deployment_name}" "${namespace}")"
    
    if [ -z "${extra_envs}" ]; then
        echo "false"
    elif [[ "${RHDH_INSTANCE_PROVIDED}" == "false" ]] && [[ "${extra_env_secret_exists}" == "false" ]]; then
        echo "false"
    else
        echo "true"
    fi
}

# Attach given extra environment variable secret to target deployment
attach_extra_envs_to_deployment() {
    local extra_envs_secret=$1
    local deployment=$2
    local namespace=$3

    kubectl get deploy $deployment -n $namespace -o yaml | \
        yq ".spec.template.spec.containers[0].envFrom += [{\"secretRef\": {\"name\": \"${extra_envs_secret}\"}}] |
            .spec.template.spec.containers[0].envFrom |= unique_by(.secretRef.name)" | \
        kubectl apply -f - >/dev/null

    return $?
}

# Attach given extra environment variable secret to target Backstage CR
attach_extra_envs_to_cr() {
    local extra_envs_secret=$1
    local cr_name=$2
    local namespace=$3

    kubectl -n $namespace get backstage $cr_name -o yaml | \
        yq ".spec.application.extraEnvs.secrets += [{\"name\": \"${extra_envs_secret}\"}] | 
            .spec.application.extraEnvs.secrets |= unique_by(.name)" -M | \
        kubectl apply -n $namespace -f - >/dev/null

    return $?
}

# Builds appconfig data for template catalog
build_catalog_appconfig() {
    local catalogs_file=$1
    local appconfig_data="${2:-"$(yq -n -M)"}"
    local catalog_locations=$(yq '.catalogs | map({"type": "url", "target": .})' $catalogs_file -M -I=0 -o=json)
    
    echo "${appconfig_data}" | yq ".catalog.locations = ${catalog_locations}" -M -
}

# Builds appconfig data for GitHub integration
build_gh_appconfig() {
    local appconfig_data="${1:-"$(yq -n -M)"}"

    echo "${appconfig_data}" | yq ".auth.providers.github.production.clientId = \"\${GITHUB__APP__CLIENT__ID}\" |
        .auth.providers.github.production.clientSecret = \"\${GITHUB__APP__CLIENT__SECRET}\" |
        .catalog.providers.github.providerId.organization = \"\${GITHUB__ORG__NAME}\" |
        .catalog.providers.github.providerId.schedule.frequency.minutes = ${CATALOG_GITHUB_SCHEDULE_FREQUENCY_MINUTES} |
        .catalog.providers.github.providerId.schedule.initialDelay.seconds = ${CATALOG_GITHUB_SCHEDULE_INITIALDELAY_SECONDS} |
        .catalog.providers.github.providerId.schedule.timeout.minutes = ${CATALOG_GITHUB_SCHEDULE_TIMEOUT_MINUTES} |
        .catalog.providers.githubOrg.githubUrl = \"https://\${GITHUB__HOST}\" |
        .catalog.providers.githubOrg.orgs = [\"\${GITHUB__ORG__NAME}\"] |
        .catalog.providers.githubOrg.schedule.frequency.minutes = ${CATALOG_GITHUB_SCHEDULE_FREQUENCY_MINUTES} |
        .catalog.providers.githubOrg.schedule.initialDelay.seconds = ${CATALOG_GITHUB_SCHEDULE_INITIALDELAY_SECONDS} |
        .catalog.providers.githubOrg.schedule.timeout.minutes = ${CATALOG_GITHUB_SCHEDULE_TIMEOUT_MINUTES} |
        .integrations.github[0].host = \"\${GITHUB__HOST}\" |
        .integrations.github[0].apps[0].appId = \"\${GITHUB__APP__ID}\" |
        .integrations.github[0].apps[0].clientId = \"\${GITHUB__APP__CLIENT__ID}\" |
        .integrations.github[0].apps[0].clientSecret = \"\${GITHUB__APP__CLIENT__SECRET}\" |
        .integrations.github[0].apps[0].webhookUrl = \"\${GITHUB__APP__WEBHOOK__URL}\" |
        .integrations.github[0].apps[0].webhookSecret = \"\${GITHUB__APP__WEBHOOK__SECRET}\" |
        .integrations.github[0].apps[0].privateKey = \"\${GITHUB__APP__PRIVATE_KEY}\"" -M -
}

# Builds appconfig data for GitLab integration
build_gl_appconfig() {
    local appconfig_data="${1:-"$(yq -n -M)"}"

    echo "${appconfig_data}" | yq ".auth.providers.gitlab.production.clientId = \"\${GITLAB__APP__CLIENT__ID}\" |
        .auth.providers.gitlab.production.clientSecret = \"\${GITLAB__APP__CLIENT__SECRET}\" |
        .signInPage = \"gitlab\" |
        .catalog.providers.gitlab.providerId.host = \"\${GITLAB__HOST}\" |
        .catalog.providers.gitlab.providerId.group = \"\${GITLAB__GROUP__NAME}\" |
        .catalog.providers.gitlab.providerId.orgEnabled = \"\${GITLAB__ORG__ENABLED}\" |
        .catalog.providers.gitlab.providerId.schedule.frequency.minutes = ${CATALOG_GITLAB_SCHEDULE_FREQUENCY_MINUTES} |
        .catalog.providers.gitlab.providerId.schedule.initialDelay.seconds = ${CATALOG_GITLAB_SCHEDULE_INITIALDELAY_SECONDS} |
        .catalog.providers.gitlab.providerId.schedule.timeout.minutes = ${CATALOG_GITLAB_SCHEDULE_TIMEOUT_MINUTES} |

        .integrations.gitlab[0].host = \"\${GITLAB__HOST}\" |
        .integrations.gitlab[0].token = \"\${GITLAB__TOKEN}\"" -M -
}

# Builds appconfig data for sign in provider
build_signin_appconfig() {
    local appconfig_data="${1:-"$(yq -n -M)"}"

    echo "${appconfig_data}" | yq ".signInPage = env(RHDH_SIGNIN_PROVIDER)" -M
}

# Builds appconfig data for Quay integration
build_quay_appconfig() {
    local appconfig_data="${1:-"$(yq -n -M)"}"

    echo "${appconfig_data}" | yq ".proxy.endpoints./quay/api.headers.Authorization = \"Bearer \${QUAY__API_TOKEN}\"" -M -
}

# Builds appconfig data for LightSpeed integration
build_ls_appconfig() {
    local positional_args=()
    local use_lightspeed_token="false"

    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--token)
                use_lightspeed_token="true"
                shift
                ;;
            -*|--*)
                echo "Unknown option $1"
                return 1
                ;;
            *)
                positional_args+=("$1") # save positional arg
                shift # past argument
                ;;
        esac
    done

    set -- "${positional_args[@]}" # restore positional parameters
    local appconfig_data="${1:-"$(yq -n -M)"}"

    appconfig_data=$(echo "${appconfig_data}" | yq ".proxy.endpoints./lightspeed/api.target = \"${LIGHTSPEED_MODEL_URL}\"" -M -)
    if [[ "${use_lightspeed_token}" == "true" ]]; then
        echo "${appconfig_data}" | yq ".proxy.endpoints./lightspeed/api.headers.Authorization = \"Bearer \${LIGHTSPEED_API_TOKEN}\"" -M -
    else
        echo "${appconfig_data}"
    fi
}

# Creates the appconfig configmap for RHDH
create_appconfig() {
    local namespace=$1
    local appconfig_data="${2:-"$(yq -n -M)"}"
    local configmap_file=${3:-"${BASE_DIR}/resources/developer-hub-app-config.yaml"}

    APPCONFIG_DATA=$appconfig_data yq ".data[\"app-config.extra.yaml\"] = strenv(APPCONFIG_DATA)" ${configmap_file} | \
        kubectl -n $namespace apply -f - >/dev/null

    return $?
}

# Patches given deployment under a given namespace to mount the appconfig configmap
attach_appconfig_to_deployment() {
    local appconfig_name=$1
    local deployment=$2
    local namespace=$3

    kubectl get deploy $deployment -n $namespace -o yaml | \
        yq ".spec.template.spec.volumes += {\"name\": \"${appconfig_name}\", \"configMap\": {\"name\": \"${appconfig_name}\", \"defaultMode\": 420, \"optional\": false}} | 
            .spec.template.spec.containers[0].volumeMounts += {\"name\": \"${appconfig_name}\", \"readOnly\": true, \"mountPath\": \"/opt/app-root/src/app-config.extra.yaml\", \"subPath\": \"app-config.extra.yaml\"} |
            .spec.template.spec.containers[0].args += [\"--config\", \"/opt/app-root/src/app-config.extra.yaml\"]" | \
        kubectl apply -f - >/dev/null

    return $?
}

# Patches given Backstage CR under a given namespace to mount the appconfig configmap
attach_appconfig_to_cr() {
    local appconfig_name=$1
    local cr_name=$2
    local namespace=$3

    kubectl -n $namespace get backstage $cr_name -o yaml | \
        yq ".spec.application.appConfig.configMaps += [{\"name\": \"${appconfig_name}\"}] | 
            .spec.application.appConfig.configMaps |= unique_by(.name)" -M -I=0 -o=json | \
        kubectl apply -n $namespace -f - >/dev/null
    
    return $?
}

# Returns true if the dynamic plugins configmap should be patched and false if it should be created
is_plugins_patch() {
    local existing_plugins_configmap=$1
    local deployment_name=$2
    local namespace=$3
    local plugins_configmap_exists="$(attached_plugins_exists "${deployment_name}" "${namespace}")"
    
    if [[ "${plugins_configmap_exists}" == "true" ]] && [[ $RHDH_INSTANCE_PROVIDED != "true" ]]; then
        echo "true"
    elif [[ $RHDH_INSTANCE_PROVIDED == "true" ]] && [ ! -z "${existing_plugins_configmap}" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Creates dynamic plugins configmap
create_plugins() {
    local plugins_configmap=$1
    local deployment_name=$2
    local namespace=$3

    if [[ $RHDH_INSTANCE_PROVIDED == "true" ]]; then
        yq ".metadata.name = \"${plugins_configmap}\" |
            .metadata.annotations.\"rhdhpai.redhat.com/rhdh-installer-instance\" = \"${deployment_name}\"" \
            $BASE_DIR/resources/developer-hub-dynamic-plugins.yaml | kubectl -n $namespace apply -f -
    else
        yq ".metadata.name = \"${plugins_configmap}\" |
            .metadata.annotations.\"rhdhpai.redhat.com/rhdh-installer-instance\" = \"${deployment_name}\" |
            .metadata.annotations.\"rhdh.redhat.com/backstage-name\" = \"${BACKSTAGE_CR_NAME}\"" \
            $BASE_DIR/resources/developer-hub-dynamic-plugins.yaml | kubectl -n $namespace apply -f -
    fi

    return $?
}

# Patches plugin list from a given YAML file into a given plugins configmap under a given namespace
patch_plugins() {
    local plugins=$1
    local plugins_configmap=$2
    local namespace=$3

    # Grab configmap and parse out the defined yaml file inside of its data to a temp file
    kubectl get configmap $plugins_configmap -n $namespace -o yaml | yq '.data["dynamic-plugins.yaml"]' > temp-dynamic-plugins.yaml
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Edit the temp file to include the plugins
    yq -i ".plugins += $(yq '.plugins' $plugins -M -o json) | .plugins |= unique_by(.package)" temp-dynamic-plugins.yaml
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Patch the configmap that is deployed to update the defined yaml inside of it
    kubectl patch configmap $plugins_configmap -n $namespace \
        --type='merge' \
        -p="{\"data\":{\"dynamic-plugins.yaml\":\"$(echo "$(cat temp-dynamic-plugins.yaml)" | sed 's/"/\\"/g' | sed 's/$/\\n/g' | tr -d '\n')\"}}"
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Cleanup temp files
    rm temp-dynamic-plugins.yaml

    return $?
}

# Returns true if the dynamic plugins configmap is attached to given deployment under given namespace else returns false
is_plugins_attached() {
    local plugins_configmap=$1
    local deployment_name=$2
    local namespace=$3
    local plugins_volumes="$(kubectl get deployment $deployment_name -n $namespace -o=jsonpath='{.spec.template.spec}' --ignore-not-found |
        yq ".volumes[] | select(.configMap.name == \"${plugins_configmap}\") | .configMap.name" -M)"
    local plugins_configmap_exists="$(attached_plugins_exists "${deployment_name}" "${namespace}")"
    
    if [ -z "${plugins_volumes}" ]; then
        echo "false"
    elif [[ "${RHDH_INSTANCE_PROVIDED}" == "false" ]] && [[ "${plugins_configmap_exists}" == "false" ]]; then
        echo "false"
    else
        echo "true"
    fi
}

attach_plugins_to_deployment() {
    local plugins_configmap=$1
    local deployment=$2
    local namespace=$3

    kubectl get deploy $deployment -n $namespace -o yaml | \
        yq ".spec.template.spec.volumes += {\"name\": \"${plugins_configmap}\", \"configMap\": {\"name\": \"${plugins_configmap}\", \"defaultMode\": 420, \"optional\": false}} | 
            .spec.template.spec.initContainers[0].volumeMounts += {\"name\": \"${plugins_configmap}\", \"readOnly\": true, \"mountPath\": \"/opt/app-root/src/dynamic-plugins.yaml\", \"subPath\": \"dynamic-plugins.yaml\"}" | \
        kubectl apply -f - >/dev/null
    
    return $?
}

attach_plugins_to_cr() {
    local plugins_configmap=$1
    local cr_name=$2
    local namespace=$3

    kubectl -n $namespace get backstage $cr_name -o yaml | \
        yq ".spec.application.dynamicPluginsConfigMapName = \"${plugins_configmap}\"" -M | \
        kubectl apply -n $namespace -f - >/dev/null
    
    return $?
}

configure_dh() {
    # Use existing variables if RHDH instance is provided
    if [[ $RHDH_INSTANCE_PROVIDED != "true" ]] && [[ $RHDH_INSTANCE_PROVIDED != "false" ]]; then
        echo -n "RHDH_INSTANCE_PROVIDED needs to be set to either 'true' or 'false'"
        echo "FAIL"
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
        if  [[ $RHDH_GITLAB_INTEGRATION == "true" ]] && [ -z "${GITLAB__ORG__ENABLED}" ] && [[ $GITLAB__HOST == "gitlab.com" ]]
        then
            GITLAB__ORG__ENABLED='true' # required for gitlab.com, see https://backstage.io/docs/integrations/gitlab/org#users
        elif [[ $RHDH_GITLAB_INTEGRATION == "true" ]] && [ -z "${GITLAB__ORG__ENABLED}" ]
        then
            prompt=''
            until [[ "${GITLAB__ORG__ENABLED}" == "true" ]] || [[ "${GITLAB__ORG__ENABLED}" == "false" ]]; do
                read -p "Is GitLab Organizations enabled? (y/n): " prompt

                case "$prompt" in
                    y)
                        GITLAB__ORG__ENABLED='true'
                        ;;
                    n)
                        GITLAB__ORG__ENABLED='false'
                        ;;
                    *)
                        echo 'Please enter "y" or "n", try again.'
                        ;;
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
        echo -n "Plugins configmap '${RHDH_PLUGINS_CONFIGMAP}' not found!"
        echo "FAIL"
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
        echo -n "Extra env secret '${RHDH_EXTRA_ENV_SECRET}' not found!"
        echo "FAIL"
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
        echo -n "ArgoCD config 'argocd-config' not found!"
        echo "FAIL"
        return 1
    fi
    if [ -z "$(kubectl -n $NAMESPACE get secret "rhdh-argocd-secret" -o name --ignore-not-found)" ]; then
        echo -n "ArgoCD secret 'rhdh-argocd-secret' not found!"
        echo "FAIL"
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
