#!/bin/bash

# Constants
GITHUB_DOCS_URL='https://pipelinesascode.com/docs/install/github_apps/'
DEFAULT_RHDH_DEPLOYMENT="backstage-ai-rh-developer-hub" # deployment created by rhdh operator by default
EXTRA_ENV_SECRET="ai-rh-developer-hub-env" # secret created by rhdh installer to store private env vars

# Variables
BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"
RHDH_DEPLOYMENT="${DEFAULT_RHDH_DEPLOYMENT}"
RHDH_ROUTE="${RHDH_ROUTE:-$RHDH_DEPLOYMENT}"
RHDH_EXTRA_ENV_SECRET="${EXTRA_ENV_SECRET}"
RHDH_GITHUB_INTEGRATION=${RHDH_GITHUB_INTEGRATION:-true}
RHDH_GITLAB_INTEGRATION=${RHDH_GITLAB_INTEGRATION:-false}
NAMESPACE=${NAMESPACE:-"ai-rhdh"}
PIPELINES_NAMESPACE=${PIPELINES_NAMESPACE:-"openshift-pipelines"}

# Secret variables
GITHUB__APP__WEBHOOK__URL=${GITHUB__APP__WEBHOOK__URL:-''}
GITHUB__APP__WEBHOOK__SECRET=${GITHUB__APP__WEBHOOK__SECRET:-''}

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

# Waiting for RHDH deployment
# Waits for the deployment of the developer hub instance to finish before proceeding.
echo -n "* Waiting for RHDH deployment: "
until kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; do
    echo -n "."
    sleep 3
done
until kubectl get route -n ${NAMESPACE} ${RHDH_ROUTE} >/dev/null 2>&1; do
    echo -n "."
    sleep 3
done
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi
echo "OK"

# Fetching Homepage URL
echo -n "* Fetching Homepage URL: "
HOMEPAGE_URL="$(kubectl get routes -n ${NAMESPACE} ${RHDH_ROUTE} -o jsonpath="https://{.spec.host}")"
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi
echo "OK"

if [[ $RHDH_GITHUB_INTEGRATION == "true" ]]; then
    # Fetching Webhook URL
    echo -n "* Fetching Webhook URL: "
    if [ -z "${GITHUB__APP__WEBHOOK__URL}" ]; then
        if [ -z "${RHDH_EXTRA_ENV_SECRET}" ]; then
            GITHUB__APP__WEBHOOK__URL="$(kubectl get routes -n "${PIPELINES_NAMESPACE}" pipelines-as-code-controller -o jsonpath="https://{.spec.host}")"
        elif [ -z "$(kubectl -n ${NAMESPACE} get secret ${RHDH_EXTRA_ENV_SECRET} --ignore-not-found -o name)" ]; then
            if [ $? -ne 0 ]; then
                echo "FAIL"
                exit 1
            fi
            echo "[FAIL] Extra environment variable secret '${RHDH_EXTRA_ENV_SECRET}' not found!"
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

    # Fetching Webhook Secret
    echo -n "* Fetching Webhook Secret: "
    if [ -z "${GITHUB__APP__WEBHOOK__SECRET}" ]; then
        if [ ! -z "${RHDH_EXTRA_ENV_SECRET}" ] && [ -z "$(kubectl -n ${NAMESPACE} get secret ${RHDH_EXTRA_ENV_SECRET} --ignore-not-found -o name)" ]; then
            if [ $? -ne 0 ]; then
                echo "FAIL"
                exit 1
            fi
            echo "[FAIL] Extra environment variable secret '${RHDH_EXTRA_ENV_SECRET}' not found!"
            exit 1
        elif [ ! -z "${RHDH_EXTRA_ENV_SECRET}" ] && \
            [[ "$(kubectl -n ${NAMESPACE} get secret ${RHDH_EXTRA_ENV_SECRET} -o yaml | yq '.data.GITHUB__APP__WEBHOOK__SECRET')" != "null" ]]; then
            if [ $? -ne 0 ]; then
                echo "FAIL"
                exit 1
            fi
            GITHUB__APP__WEBHOOK__SECRET="$(kubectl -n ${NAMESPACE} get secret ${RHDH_EXTRA_ENV_SECRET} -o yaml | yq '.data.GITHUB__APP__WEBHOOK__SECRET' | base64 -d)"
            if [ $? -ne 0 ]; then
                echo "FAIL"
                exit 1
            fi
        fi
    fi
    echo "OK"
fi

# Print installation info
echo ''
echo "RHDH Installation Info:"
if [[ $RHDH_GITHUB_INTEGRATION == "true" ]]; then
    CALLBACK_URL="${HOMEPAGE_URL}/api/auth/github/handler/frame"

    echo "Docs URL:       ${GITHUB_DOCS_URL}"
    echo "Homepage URL:   ${HOMEPAGE_URL}"
    echo "GitHub Callback URL:   ${CALLBACK_URL}"
    echo "Webhook URL:    ${GITHUB__APP__WEBHOOK__URL}"
    echo "Webhook Secret: ${GITHUB__APP__WEBHOOK__SECRET}"
fi
if [[ $RHDH_GITLAB_INTEGRATION == "true" ]]; then
    CALLBACK_URL="${HOMEPAGE_URL}/api/auth/gitlab/handler/frame"

    echo "GitLab Callback URL:   ${CALLBACK_URL}"
fi
