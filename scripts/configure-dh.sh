#!/bin/bash

# Constants
DEFAULT_RHDH_DEPLOYMENT="backstage-ai-rh-developer-hub" # deployment created by rhdh operator by default
PLUGIN_CONFIGMAP="backstage-dynamic-plugins-ai-rh-developer-hub" # configmap created by rhdh operator for plugins by default

# Variables
BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))/.."
RHDH_DEPLOYMENT="${DEFAULT_RHDH_DEPLOYMENT}"
RHDH_PLUGINS_CONFIGMAP="${PLUGIN_CONFIGMAP}"
NAMESPACE=${NAMESPACE:-"ai-rhdh"}
EXISTING_NAMESPACE=${EXISTING_NAMESPACE:-''}
EXISTING_DEPLOYMENT=${EXISTING_DEPLOYMENT:-''}
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
    RHDH_PLUGINS_CONFIGMAP="${RHDH_PLUGINS}"
fi

# Reading secrets
# Reads secrets either from environment variables or user input
echo "* Reading secrets: "

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
until [ ! -z "${QUAY__API_TOKEN}" ]; do
    read -p "Enter your Quay API Token: " QUAY__API_TOKEN
    if [ -z "${QUAY__API_TOKEN}" ]; then
        echo "No Quay API Token entered, try again."
    fi
done

echo "OK"
