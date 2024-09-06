#!/bin/bash

# Variables
BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"
NAMESPACE=${NAMESPACE:-"ai-rhdh"}
PIPELINES_NAMESPACE=${PIPELINES_NAMESPACE:-"openshift-pipelines"}
PIPELINES_SECRET_NAME=${PIPELINES_SECRET_NAME:-'rhdh-pipelines-secret'}

# Secret variables
GITHUB__APP__ID=${GITHUB__APP__ID:-''}
GITHUB__APP__WEBHOOK__SECRET=${GITHUB__APP__WEBHOOK__SECRET:-''}
GITHUB__APP__PRIVATE_KEY=${GITHUB__APP__PRIVATE_KEY:-''}

# Constants
CRD="tektonconfigs"

# Reading secrets
# Reads secrets either from environment variables or user input
echo "* Reading secrets: "
# Reads GitHub Org App ID
until [ ! -z "${GITHUB__APP__ID}" ]; do
    read -p "Enter your GitHub App ID: " GITHUB__APP__ID
    if [ -z "${GITHUB__APP__ID}" ]; then
        echo "No GitHub App ID entered, try again."
    fi
done

# Reads GitHub Org App Webhook Secret
# Optional: If left blank during user prompt, one is generated instead
if [ -z "${GITHUB__APP__WEBHOOK__SECRET}" ]; then
    read -p "Enter your GitHub App Webhook Secret (Optional): " GITHUB__APP__WEBHOOK__SECRET
    if [ -z "${GITHUB__APP__WEBHOOK__SECRET}" ]; then
        GITHUB__APP__WEBHOOK__SECRET="$(openssl rand -hex 20)"
        echo "Use the following as your GitHub App Webhook Secret: ${GITHUB__APP__WEBHOOK__SECRET}"
    fi
fi

# Reads GitHub Org App Private Key
until [ ! -z "${GITHUB__APP__PRIVATE_KEY}" ]; do
    read -p "Enter your GitHub App Private Key (Use CTRL-D when finished): " -d $'\04' GITHUB__APP__PRIVATE_KEY
    if [ -z "${GITHUB__APP__PRIVATE_KEY}" ]; then
        echo "No GitHub App Private Key entered, try again."
    fi
done
echo "OK"

# Waiting for CRD
# Waits for TektonConfig CRD to become avaiable when performing deployment of the pipelines
# services.
echo -n "* Waiting for '$CRD' CRD: "
while [ $(kubectl api-resources | grep -c "^$CRD ") = "0" ] ; do
    echo -n "."
    sleep 3
done
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
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
    exit 1
fi
echo "OK"

# Update the TektonConfig resource
# Updates Tekton config CR to have setup with target namespace and 
# compatiablty with RHDH instances
echo -n "* Update the TektonConfig resource: "
until kubectl get tektonconfig config >/dev/null 2>&1; do
    echo -n "."
    sleep 3
done
TEKTON_CONFIG=$(jq ".spec.chain.\"transparency.url\" = \"http://rekor-server.${NAMESPACE}.svc\"" $BASE_DIR/../resources/tekton-config.json -Mc)
kubectl patch tektonconfig config --type 'merge' --patch "${TEKTON_CONFIG}" >/dev/null
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi
echo "OK"

# Configuring Pipelines-as-Code
# Configuring secrets tied to pipelines to interface with the target GitHub organization.
echo -n "* Configuring Pipelines-as-Code: "
if [ "$(kubectl -n "${NAMESPACE}" get secret "${PIPELINES_SECRET_NAME}" -o name --ignore-not-found | wc -l)" = "0" ]; then
    WEBHOOK_SECRET=$(sed "s/'/\\'/g" <<< ${GITHUB__APP__WEBHOOK__SECRET} | sed 's/"/\"/g')
    kubectl -n "${NAMESPACE}" create secret generic "${PIPELINES_SECRET_NAME}" \
        --from-literal="webhook-github-secret=${WEBHOOK_SECRET}" \
        --from-literal="webhook-url=$(kubectl get routes -n "${PIPELINES_NAMESPACE}" pipelines-as-code-controller -o jsonpath="https://{.spec.host}")" >/dev/null
else
    WEBHOOK_SECRET="$(kubectl -n "${NAMESPACE}" get secret "${PIPELINES_SECRET_NAME}" ) -o jsonpath="{.data.webhook-github-secret}" | base64 -d"
fi
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi

if [ "$(kubectl get secret -n "${PIPELINES_NAMESPACE}" "pipelines-as-code-secret" -o name --ignore-not-found | wc -l)" = "0" ]; then
    kubectl -n "${PIPELINES_NAMESPACE}" create secret generic pipelines-as-code-secret \
        --from-literal github-application-id="${GITHUB__APP__ID}" \
        --from-literal github-private-key="${GITHUB__APP__PRIVATE_KEY}" \
        --from-literal webhook.secret="${WEBHOOK_SECRET}" \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    
    if [ $? -ne 0 ]; then
        echo "FAIL"
        exit 1
    fi
fi
echo "OK"
