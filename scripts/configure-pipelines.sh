#!/bin/bash

# Constants
DEFAULT_RHDH_DEPLOYMENT="backstage-ai-rh-developer-hub" # deployment created by rhdh operator by default
PLUGIN_CONFIGMAP="backstage-dynamic-plugins-ai-rh-developer-hub" # configmap created by rhdh operator for plugins by default
CRD="tektonconfigs"

# Variables
BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))/.."
RHDH_DEPLOYMENT="${DEFAULT_RHDH_DEPLOYMENT}"
RHDH_PLUGINS_CONFIGMAP="${PLUGIN_CONFIGMAP}"
NAMESPACE=${NAMESPACE:-"ai-rhdh"}
PIPELINES_NAMESPACE=${PIPELINES_NAMESPACE:-"openshift-pipelines"}
PIPELINES_SECRET_NAME=${PIPELINES_SECRET_NAME:-'rhdh-pipelines-secret'}
EXISTING_NAMESPACE=${EXISTING_NAMESPACE:-''}
EXISTING_DEPLOYMENT=${EXISTING_DEPLOYMENT:-''}
RHDH_PLUGINS=${RHDH_PLUGINS:-''}
RHDH_INSTANCE_PROVIDED=${RHDH_INSTANCE_PROVIDED:-false}

# Secret variables
GITHUB__APP__ID=${GITHUB__APP__ID:-''}
GITHUB__APP__WEBHOOK__SECRET=${GITHUB__APP__WEBHOOK__SECRET:-''}
GITHUB__APP__PRIVATE_KEY=${GITHUB__APP__PRIVATE_KEY:-''}
GITOPS__GIT_TOKEN=${GITOPS__GIT_TOKEN:-''}
GITLAB__TOKEN=${GITLAB__TOKEN:-''}
QUAY__DOCKERCONFIGJSON=${QUAY__DOCKERCONFIGJSON:-''}

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
    echo ""
    if [ -z "${GITHUB__APP__PRIVATE_KEY}" ]; then
        echo "No GitHub App Private Key entered, try again."
    fi
done

# Reads Git PAT
# Optional: If left blank during user prompt, the namespace secret will not be created
if [ -z "${GITOPS__GIT_TOKEN}" ]; then
    read -p "Enter your Git Token (Optional): " GITOPS__GIT_TOKEN
fi

# Reads GitLab PAT
# Optional: If left blank during user prompt, the namespace secret will not be created
if [ -z "${GITLAB__TOKEN}" ]; then
    read -p "Enter your GitLab Token (Optional): " GITLAB__TOKEN
fi

# Reads Quay DockerConfig JSON
# Optional: If left blank during user prompt, the namespace secret will not be created
if [ -z "${QUAY__DOCKERCONFIGJSON}" ]; then
    read -p "Enter your Quay DockerConfig JSON (Optional|Use CTRL-D when finished): " -d $'\04' QUAY__DOCKERCONFIGJSON
    echo ""
fi
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
TEKTON_CONFIG=$(yq ".spec.chain.\"transparency.url\" = \"http://rekor-server.${NAMESPACE}.svc\"" $BASE_DIR/resources/tekton-config.yaml -M -I=0 -o='json')
kubectl patch tektonconfig config --type 'merge' --patch "${TEKTON_CONFIG}" >/dev/null
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi
echo "OK"

# Configuring Pipelines-as-Code
# Configuring secrets tied to pipelines to interface with the target GitHub organization.
echo -n "* Configuring Pipelines-as-Code: "
if [ "$(kubectl -n "${NAMESPACE}" get secret "${PIPELINES_SECRET_NAME}" -o name --ignore-not-found | wc -l | tr -d '[:space:]')" = "0" ]; then
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

if [ "$(kubectl get secret -n "${PIPELINES_NAMESPACE}" "pipelines-as-code-secret" -o name --ignore-not-found | wc -l | tr -d '[:space:]')" = "0" ]; then
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

# Configure Namespaces
# Configuring namespaces with needed resources
echo -n "* Configuring Namespaces: "
while ! kubectl get secrets -n openshift-pipelines signing-secrets >/dev/null 2>&1; do
    echo -n "_"
    sleep 2
done
echo -n "."
COSIGN_SIGNING_PUBLIC_KEY=""
while [ -z "${COSIGN_SIGNING_PUBLIC_KEY:-}" ]; do
    echo -n "_"
    sleep 2
    COSIGN_SIGNING_PUBLIC_KEY=$(kubectl get secrets -n openshift-pipelines signing-secrets -o jsonpath='{.data.cosign\.pub}' 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -n "FAIL"
        exit 1
    fi
done
for NAMESPACE_SUFFIX in "development" "prod" "stage"; do
    APP_NAMESPACE="${NAMESPACE}-app-${NAMESPACE_SUFFIX}"

    cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Namespace
metadata:
  labels:
    argocd.argoproj.io/managed-by: $NAMESPACE
  name: $APP_NAMESPACE
EOF
    if [ $? -ne 0 ]; then
        echo -n "FAIL"
        exit 1
    fi

    SECRET_NAME="cosign-pub"
    if [ -n "$COSIGN_SIGNING_PUBLIC_KEY" ]; then
        cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
data:
    cosign.pub: $COSIGN_SIGNING_PUBLIC_KEY
kind: Secret
metadata:
    labels:
        app.kubernetes.io/instance: default
        app.kubernetes.io/part-of: tekton-chains
        operator.tekton.dev/operand-name: tektoncd-chains
    name: $SECRET_NAME
    namespace: $APP_NAMESPACE
type: Opaque
EOF
        if [ $? -ne 0 ]; then
            echo -n "FAIL"
            exit 1
        fi
        echo -n "."
    fi
    SECRET_NAME="gitlab-auth-secret"
    if [ -n "$GITLAB__TOKEN" ]; then
        kubectl -n $APP_NAMESPACE create secret generic "$SECRET_NAME" \
            --from-literal=password=$GITLAB__TOKEN \
            --from-literal=username=oauth2 \
            --type=kubernetes.io/basic-auth \
            --dry-run=client -o yaml | kubectl -n $APP_NAMESPACE apply --filename - --overwrite=true >/dev/null
        if [ $? -ne 0 ]; then
            echo -n "FAIL"
            exit 1
        fi
        echo -n "."
    fi
    SECRET_NAME="gitops-auth-secret"
    if [ -n "$GITOPS__GIT_TOKEN" ]; then
        kubectl -n $APP_NAMESPACE create secret generic "$SECRET_NAME" \
            --from-literal=password=$GITOPS__GIT_TOKEN \
            --type=kubernetes.io/basic-auth \
            --dry-run=client -o yaml | kubectl -n $APP_NAMESPACE apply --filename - --overwrite=true >/dev/null
        if [ $? -ne 0 ]; then
            echo -n "FAIL"
            exit 1
        fi
        echo -n "."
    fi
    SECRET_NAME="pipelines-secret"
    if [ -n "$GITHUB__APP__WEBHOOK__SECRET" ]; then
        kubectl -n $APP_NAMESPACE create secret generic "$SECRET_NAME" \
            --from-literal=webhook.secret=$GITHUB__APP__WEBHOOK__SECRET \
            --dry-run=client -o yaml | kubectl -n $APP_NAMESPACE apply --filename - --overwrite=true >/dev/null
        if [ $? -ne 0 ]; then
            echo -n "FAIL"
            exit 1
        fi
        echo -n "."
    fi
    SECRET_NAME="rhdh-image-registry-token"
    if [ -n "$QUAY__DOCKERCONFIGJSON" ]; then
        DATA=$(mktemp)
        echo -n "$QUAY__DOCKERCONFIGJSON" >"$DATA"
        kubectl -n $APP_NAMESPACE create secret docker-registry "$SECRET_NAME" \
            --from-file=.dockerconfigjson="$DATA" --dry-run=client -o yaml | \
            kubectl -n $APP_NAMESPACE apply --filename - --overwrite=true >/dev/null
        if [ $? -ne 0 ]; then
            echo -n "FAIL"
            exit 1
        fi
        rm "$DATA"
        echo -n "."
        while ! kubectl -n $APP_NAMESPACE get serviceaccount pipeline >/dev/null; do
            sleep 2
            echo -n "_"
        done
        for SA in default pipeline; do
            kubectl -n $APP_NAMESPACE patch serviceaccounts "$SA" --patch "
        secrets:
        - name: $SECRET_NAME
        imagePullSecrets:
        - name: $SECRET_NAME
        " >/dev/null
            if [ $? -ne 0 ]; then
                echo -n "FAIL"
                exit 1
            fi
            echo -n "."
        done
        echo -n "."
    fi
done
echo "OK"

# Include Tekton plugins
# Patches dynamic plugins ConfigMap with list of Tekton plugins
echo -n "* Patching in Tekton plugins: "
# Grab configmap and parse out the defined yaml file inside of its data to a temp file
kubectl get configmap $RHDH_PLUGINS_CONFIGMAP -n $NAMESPACE -o yaml | yq '.data["dynamic-plugins.yaml"]' > temp-dynamic-plugins.yaml
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi

# Edit the temp file to include the tekton plugins
yq -i ".plugins += $(yq '.plugins' $BASE_DIR/dynamic-plugins/tekton-plugins.yaml -M -o json) | .plugins |= unique_by(.package)" temp-dynamic-plugins.yaml
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi

# Patch the configmap that is deployed to update the defined yaml inside of it
kubectl patch configmap $RHDH_PLUGINS_CONFIGMAP -n $NAMESPACE \
--type='merge' \
-p="{\"data\":{\"dynamic-plugins.yaml\":\"$(echo "$(cat temp-dynamic-plugins.yaml)" | sed 's/"/\\"/g' | sed 's/$/\\n/g' | tr -d '\n')\"}}"
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi

# Cleanup temp files
rm temp-dynamic-plugins.yaml

echo "OK"

# Configure TLS
# Patches Backstage CR to configure cluster TLS
echo -n "* Configuring TLS: "
kubectl get deploy $RHDH_DEPLOYMENT -n $NAMESPACE -o yaml | \
    yq '.spec.template.spec.containers[0].env += {"name": "NODE_TLS_REJECT_UNAUTHORIZED", "value": "0"} | 
    .spec.template.spec.containers[0].env |= unique_by(.name)' | \
    kubectl apply -f -
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi
echo "OK"

# Add Tekton information and plugin to backstage deployment data
echo -n "* Adding Tekton information and plugin to backstage deployment data: "
K8S_SA_SECRET_NAME=$(kubectl get secrets -n "$NAMESPACE" -o name | grep rhdh-kubernetes-plugin-token- | cut -d/ -f2 | head -1)
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi
kubectl get deploy $RHDH_DEPLOYMENT -n $NAMESPACE -o yaml | \
    yq ".spec.template.spec.containers[0].env += {\"name\": \"K8S_SA_TOKEN\", \"valueFrom\": {\"secretKeyRef\": {\"name\": \"${K8S_SA_SECRET_NAME}\", \"key\": \"token\"}}} | 
    .spec.template.spec.containers[0].env |= unique_by(.name)" | \
    kubectl apply -f -
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi
echo "OK"
