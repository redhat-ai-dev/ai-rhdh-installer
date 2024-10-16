#!/bin/bash

ARGOCD_INSTANCE_PROVIDED=${ARGOCD_INSTANCE_PROVIDED:-false}
NAMESPACE=${NAMESPACE:-"ai-rhdh"}
RHDH_DEPLOYMENT="backstage-ai-rh-developer-hub" # deployment created by rhdh operator by default
DEFAULT_PLUGIN_CONFIGMAP="backstage-dynamic-plugins-ai-rh-developer-hub" # configmap created by rhdh operator for plugins by default
DEFAULT_SECRET_NAME="rhdh-argocd-secret"

BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))/.."

# ArgoCD Instance Created By Installer
if [[ $ARGOCD_INSTANCE_PROVIDED == "false" ]]; then
    # Add ConfigMap To Configure ArgoCD
    kubectl apply -n $NAMESPACE -f $BASE_DIR/resources/argocd-config.yaml
fi

EXISTING_NAMESPACE=${EXISTING_NAMESPACE:-''}
EXISTING_DEPLOYMENT=${EXISTING_DEPLOYMENT:-''}
RHDH_PLUGINS=${RHDH_PLUGINS:-''}
ARGO_USERNAME=${ARGO_USERNAME:-''}
ARGO_PASSWORD=${ARGO_PASSWORD:-''}
ARGO_HOSTNAME=${ARGO_HOSTNAME:-''}
ARGO_TOKEN=${ARGO_TOKEN:-''}

# ArgoCD Instance Brought By User
# If a user is using this step it is assumed they did not use our installer so we need ALL the information required with no assumptions
if [[ $ARGOCD_INSTANCE_PROVIDED == "true" ]]; then
    # Gather ArgoCD instance information
    echo "You have chosen to provide your own ArgoCD instance"

    until [ ! -z "${EXISTING_NAMESPACE}" ]; do
        read -p "Enter the namespace of your RHDH and ArgoCD instance: " EXISTING_NAMESPACE
        if [ -z "${EXISTING_NAMESPACE}" ]; then
            echo "No namespace entered, try again."
        fi
    done

    until [ ! -z "${EXISTING_DEPLOYMENT}" ]; do
        read -p "Enter the deployment name of your RHDH instance: " EXISTING_DEPLOYMENT
        if [ -z "${EXISTING_DEPLOYMENT}" ]; then
            echo "No deployment entered, try again."
        fi
    done

    until [ ! -z "${RHDH_PLUGINS}" ]; do
        read -p "Enter the name of the ConfigMap for your RHDH plugins: " RHDH_PLUGINS
        if [ -z "${RHDH_PLUGINS}" ]; then
            echo "No ConfigMap entered, try again."
        fi
    done

    until [ ! -z "${ARGO_USERNAME}" ]; do
        read -p "Enter your ArgoCD username: " ARGO_USERNAME
        if [ -z "${ARGO_USERNAME}" ]; then
            echo "No username entered, try again."
        fi
    done

    until [ ! -z "${ARGO_PASSWORD}" ]; do
        read -p "Enter password for $ARGO_USERNAME: " ARGO_PASSWORD
        if [ -z "${ARGO_PASSWORD}" ]; then
            echo "No password entered, try again."
        fi
    done

    until [ ! -z "${ARGO_HOSTNAME}" ]; do
        read -p "Enter your ArgoCD hostname: " ARGO_HOSTNAME
        if [ -z "${ARGO_HOSTNAME}" ]; then
            echo "No hostname entered, try again."
        fi
    done
    
    until [ ! -z "${ARGO_TOKEN}" ]; do
        read -p "Enter your ArgoCD token: " ARGO_TOKEN
        if [ -z "${ARGO_TOKEN}" ]; then
            echo "No token entered, try again."
        fi
    done
    
    echo "Creating ArgoCD secret file"
    # Create the secret in the namespace so we can connect it to rhdh TODO: need the setup namespace input
    kubectl create secret generic "rhdh-argocd-secret" \
            --from-literal="ARGOCD_API_TOKEN=$ARGO_TOKEN" \
            --from-literal="ARGOCD_HOSTNAME=$ARGO_HOSTNAME" \
            --from-literal="ARGOCD_PASSWORD=$ARGO_PASSWORD" \
            --from-literal="ARGOCD_USER=$ARGO_USERNAME" \
            -n "$EXISTING_NAMESPACE" \
            > /dev/null
    
    echo "Applying ArgoCD ConfigMaps"
    # Create the plugin and config setup configmaps in the namespace
    kubectl apply -n $EXISTING_NAMESPACE -f $BASE_DIR/resources/argocd-config.yaml
fi