#!/bin/bash

# Variables
BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"

# Check for presence of private.env file
if [ -f "$BASE_DIR/private.env" ]; then
    echo "... Sourcing private.env file found in repository root"
    source $BASE_DIR/private.env
else
    echo "... No private.env file present"
    echo "... Prompting user for input"
fi

export RHDH_GITHUB_INTEGRATION=${RHDH_GITHUB_INTEGRATION:-true}
export RHDH_GITLAB_INTEGRATION=${RHDH_GITLAB_INTEGRATION:-false}
export LIGHTSPEED_INTEGRATION=${LIGHTSPEED_INTEGRATION:-false}
export RHDH_SIGNIN_PROVIDER=${RHDH_SIGNIN_PROVIDER:-''}

# Secret variables
export GITHUB__APP__ID=${GITHUB__APP__ID:-''}
export GITHUB__APP__CLIENT__ID=${GITHUB__APP__CLIENT__ID:-''}
export GITHUB__APP__CLIENT__SECRET=${GITHUB__APP__CLIENT__SECRET:-''}
export GITHUB__APP__WEBHOOK__URL=${GITHUB__APP__WEBHOOK__URL:-''}
export GITHUB__APP__WEBHOOK__SECRET=${GITHUB__APP__WEBHOOK__SECRET:-''}
export GITHUB__APP__PRIVATE_KEY=${GITHUB__APP__PRIVATE_KEY:-''}
export GITHUB__HOST=${GITHUB__HOST:-'github.com'}
export GITHUB__ORG__NAME=${GITHUB__ORG__NAME:-''}
export GITOPS__GIT_TOKEN=${GITOPS__GIT_TOKEN:-''}
export GITLAB__APP__CLIENT__ID=${GITLAB__APP__CLIENT__ID:-''}
export GITLAB__APP__CLIENT__SECRET=${GITLAB__APP__CLIENT__SECRET:-''}
export GITLAB__TOKEN=${GITLAB__TOKEN:-''}
export GITLAB__HOST=${GITLAB__HOST:-'gitlab.com'}
export GITLAB__GROUP__NAME=${GITLAB__GROUP__NAME:-''}
export GITLAB__ORG__ENABLED=${GITLAB__ORG__ENABLED:-''}
export QUAY__DOCKERCONFIGJSON=${QUAY__DOCKERCONFIGJSON:-''}
export QUAY__API_TOKEN=${QUAY__API_TOKEN:-''}
export LIGHTSPEED_MODEL_URL=${LIGHTSPEED_MODEL_URL:-''}
export LIGHTSPEED_API_TOKEN=${LIGHTSPEED_API_TOKEN:-''}

# Skipped optional variables
export BYPASS_OPTIONAL_INPUT=''

signin_provider=''
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

    # Reads Git PAT
    until [ ! -z "${GITOPS__GIT_TOKEN}" ]; do
        read -p "Enter your Git Token: " GITOPS__GIT_TOKEN
        if [ -z "${GITOPS__GIT_TOKEN}" ]; then
            echo "No Git Token entered, try again."
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
    if [ -z "${LIGHTSPEED_API_TOKEN}" ]; then
        read -p "Enter API token for lightspeed (Optional): " LIGHTSPEED_API_TOKEN
        BYPASS_OPTIONAL_INPUT+=",LIGHTSPEED_API_TOKEN"
    fi
fi

# Reads Quay API Token
# Optional: If an API Token is not entered, there will be none provided to the developer hub app config
if [ -z "${QUAY__API_TOKEN}" ]; then
    read -p "Enter your Quay API Token (Optional): " QUAY__API_TOKEN
    BYPASS_OPTIONAL_INPUT+=",QUAY__API_TOKEN"
fi

# Reads Quay DockerConfig JSON
# Optional: If left blank during user prompt, the namespace secret will not be created
if [ -z "${QUAY__DOCKERCONFIGJSON}" ]; then
    read -p "Enter your Quay DockerConfig JSON (Optional|Use CTRL-D when finished): " -d $'\04' QUAY__DOCKERCONFIGJSON
    echo ""
    BYPASS_OPTIONAL_INPUT+=",QUAY__DOCKERCONFIGJSON"
fi

echo ''
echo "**GitOps/ArgoCD Configuration**"

bash $BASE_DIR/scripts/configure-gitops.sh
if [ $? -ne 0 ]; then
    echo "GitOps/ArgoCD Configuration: FAILED"
    exit 1
fi
echo "GitOps/ArgoCD Configuration: OK"

echo ''
echo "**Pipelines/Tekton Configuration**"

bash $BASE_DIR/scripts/configure-pipelines.sh
if [ $? -ne 0 ]; then
    echo "Pipelines/Tekton Configuration: FAILED"
    exit 1
fi
echo "Pipelines/Tekton Configuration: OK"

echo ''
echo "**Developer Hub Configuration**"

bash $BASE_DIR/scripts/configure-dh.sh
if [ $? -ne 0 ]; then
    echo "Developer Hub Configuration: FAILED"
    exit 1
fi
echo "Developer Hub Configuration: OK"

echo ''
echo "**Printing Installation Information**"

bash $BASE_DIR/scripts/install-info.sh
if [ $? -ne 0 ]; then
    echo "Printing Installation Information: FAILED"
    exit 1
fi
echo "Printing Installation Information: OK"

echo "Creating new private.env file"
if [ -f "$BASE_DIR/private.env" ]; then
    echo "... Moving old private.env to private.env.backup"
fi
bash ./scripts/store-private-env.sh
