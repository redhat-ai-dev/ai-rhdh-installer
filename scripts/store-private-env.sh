#!/bin/bash

BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))/.."

VARS=(
    "GITHUB__APP__ID"
    "GITHUB__APP__CLIENT__ID"
    "GITHUB__APP__CLIENT__SECRET"
    "GITHUB__APP__WEBHOOK__SECRET"
    "GITHUB__APP__PRIVATE_KEY"
    "GITHUB__HOST"
    "GITHUB__ORG__NAME"
    "GITOPS__GIT_TOKEN"
    "GITLAB__APP__CLIENT__ID"
    "GITLAB__APP__CLIENT__SECRET"
    "GITLAB__TOKEN"
    "GITLAB__HOST"
    "GITLAB__GROUP__NAME"
    "GITLAB__ORG__ENABLED"
    "QUAY__DOCKERCONFIGJSON"
    "QUAY__API_TOKEN"
    "RHDH_GITLAB_INTEGRATION"
    "RHDH_GITHUB_INTEGRATION"
    "LIGHTSPEED_INTEGRATION"
    "LIGHTSPEED_MODEL_URL"
    "LIGHTSPEED_API_TOKEN"
    "RHDH_SIGNIN_PROVIDER"
    "REMOTE_CLUSTER_COUNT"
)

# Store a backup of the private.env file if it exists
if [ -f "$BASE_DIR/private.env" ]; then
    cp $BASE_DIR/private.env $BASE_DIR/private.env.backup
    rm -rf $BASE_DIR/private.env
fi

touch $BASE_DIR/private.env

for ENV_VAR in "${VARS[@]}"; do
    echo "export ${ENV_VAR}='${!ENV_VAR}'" >> $BASE_DIR/private.env
done

# Store remote cluster variables dynamically
if [ ! -z "${REMOTE_CLUSTER_COUNT}" ] && [ "${REMOTE_CLUSTER_COUNT}" -gt 0 ]; then
    for ((i=1; i<=REMOTE_CLUSTER_COUNT; i++)); do
        sa_var="REMOTE_K8S_SA_${i}"
        url_var="REMOTE_K8S_URL_${i}"
        token_var="REMOTE_K8S_SA_TOKEN_${i}"
        auth_var="REMOTE_K8S_AUTH_PROVIDER_${i}"
        
        echo "export ${sa_var}='${!sa_var}'" >> $BASE_DIR/private.env
        echo "export ${url_var}='${!url_var}'" >> $BASE_DIR/private.env
        echo "export ${token_var}='${!token_var}'" >> $BASE_DIR/private.env
        echo "export ${auth_var}='${!auth_var}'" >> $BASE_DIR/private.env
    done
fi