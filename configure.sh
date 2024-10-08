#!/bin/bash

# Variables
BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"

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
