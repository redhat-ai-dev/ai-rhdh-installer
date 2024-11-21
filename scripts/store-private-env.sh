#!/bin/bash

BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))/.."

VARS=(
    "GITHUB__APP__ID"
    "GITHUB__APP__CLIENT__ID"
    "GITHUB__APP__CLIENT__SECRET"
    "GITHUB__APP__WEBHOOK__SECRET"
    "GITHUB__APP__PRIVATE_KEY"
    "GITOPS__GIT_TOKEN"
    "GITLAB__APP__CLIENT__ID"
    "GITLAB__APP__CLIENT__SECRET"
    "GITLAB__TOKEN"
    "QUAY__DOCKERCONFIGJSON"
    "QUAY__API_TOKEN"
    "RHDH_GITLAB_INTEGRATION"
    "RHDH_GITHUB_INTEGRATION"
    "LIGHTSPEED_INTEGRATION"
    "LIGHTSPEED_MODEL_URL"
    "LIGHTSPEED_API_TOKEN"
    "RHDH_SIGNIN_PROVIDER"
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