#!/bin/bash

# Variables
BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"
RHDH_GITHUB_INTEGRATION=${RHDH_GITHUB_INTEGRATION:-true}
RHDH_GITLAB_INTEGRATION=${RHDH_GITLAB_INTEGRATION:-false}

# Secret variables
export GITHUB__APP__ID=${GITHUB__APP__ID:-''}
export GITHUB__APP__CLIENT__ID=${GITHUB__APP__CLIENT__ID:-''}
export GITHUB__APP__CLIENT__SECRET=${GITHUB__APP__CLIENT__SECRET:-''}
export GITHUB__APP__WEBHOOK__URL=${GITHUB__APP__WEBHOOK__URL:-''}
export GITHUB__APP__WEBHOOK__SECRET=${GITHUB__APP__WEBHOOK__SECRET:-''}
export GITHUB__APP__PRIVATE_KEY=${GITHUB__APP__PRIVATE_KEY:-''}
export GITOPS__GIT_TOKEN=${GITOPS__GIT_TOKEN:-''}
export GITLAB__APP__CLIENT__ID=${GITLAB__APP__CLIENT__ID:-''}
export GITLAB__APP__CLIENT__SECRET=${GITLAB__APP__CLIENT__SECRET:-''}
export GITLAB__TOKEN=${GITLAB__TOKEN:-''}
export QUAY__DOCKERCONFIGJSON=${QUAY__DOCKERCONFIGJSON:-''}
export QUAY__API_TOKEN=${QUAY__API_TOKEN:-''}

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
fi

# Reads Quay API Token
# Optional: If an API Token is not entered, there will be none provided to the developer hub app config
if [ -z "${QUAY__API_TOKEN}" ]; then
    read -p "Enter your Quay API Token (Optional): " QUAY__API_TOKEN
fi

# Reads Quay DockerConfig JSON
# Optional: If left blank during user prompt, the namespace secret will not be created
if [ -z "${QUAY__DOCKERCONFIGJSON}" ]; then
    read -p "Enter your Quay DockerConfig JSON (Optional|Use CTRL-D when finished): " -d $'\04' QUAY__DOCKERCONFIGJSON
    echo ""
fi

echo "**GitOps/ArgoCD Configuration**"

bash $BASE_DIR/scripts/configure-gitops.sh
if [ $? -ne 0 ]; then
    echo "GitOps/ArgoCD Configuration: FAILED"
    exit 1
fi
echo "GitOps/ArgoCD Configuration: OK"

echo "**Pipelines/Tekton Configuration**"

bash $BASE_DIR/scripts/configure-pipelines.sh
if [ $? -ne 0 ]; then
    echo "Pipelines/Tekton Configuration: FAILED"
    exit 1
fi
echo "Pipelines/Tekton Configuration: OK"

echo "**Developer Hub Configuration**"

bash $BASE_DIR/scripts/configure-dh.sh
if [ $? -ne 0 ]; then
    echo "Developer Hub Configuration: FAILED"
    exit 1
fi
echo "Developer Hub Configuration: OK"
