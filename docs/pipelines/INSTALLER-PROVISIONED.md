## Installer Provisioned Pipelines/Tekton Configuration

This document covers the configuration of an OpenShift Pipelines/Tekton Operator after the Operator was installed using our [`ai-rhdh-installer`](../../README.md#helm-chart-installer) Helm chart.

### Script Configuration

Run `bash ./scripts/configure-pipelines.sh` from the root of this repository to start the configuration process using our configuration scripts. Please note if you changed the installation namespace used by the installer you first need to run `export NAMESPACE=<namespace-used>` as the default value is `ai-rhdh`.

### Manual Configuration

#### Step 1: TektonConfig CR
You should patch the `TektonConfig` CR called `config` with the extended configuration under [`tekton-config.yaml`](../../resources/tekton-config.yaml)
to setup Tekton for AI software template use and RHDH integration.

Before patching you will need to provide an additional field `transparency.url` under `chain` to point to the rekor server as follows:
```json
{
    "spec": {
        ...
        "chain": {
            ...
            "transparency.url": "http://rekor-server.<rhdh_namespace>.svc"
        },
        ...
    }
}
```

Now using the updated [`tekton-config.yaml`](../../resources/tekton-config.yaml) you can patch the config with the following command:
```sh
cat resources/tekton-config.yaml | kubectl patch tektonconfig config --type 'merge' --patch - >/dev/null
```

#### Step 2: RHDH Kubernetes Plugin Service Account

As part of the `ai-rhdh-installer` a service account with a token secret was created in your desired namespace with the name `rhdh-kubernetes-plugin`, token secret should have the name `rhdh-kubernetes-plugin-token`, keep note of this Secret.

#### Step 3: Create App Namespace Setup Task

In order to set up target app namespaces for the software template created components, you will need to create a Tekton Task that will trigger when the app is created from the template. You can use [dev-setup-task.yaml](../../resources/dev-setup-task.yaml) as the starting point.

First you will need to set the default values under `.spec.params`, second you will need to fetch the cosign signing public key, third set `.spec.steps[0].script` to a script that will create the needed secret resources when the Task is run.

##### Step 3.1: Set Git Token Default Value

The `git_token` parameter is set to a Personal Access Token \(PAT\) that is tied to a GitHub account that accesses the RHDH Git repositories. The default value can be set by setting the `default` field:

```yaml
- default: '<git_pat>'
  description: |
    Git token
  name: git_token
  type: string
```

##### Step 3.2: Set GitLab Token Default Value

The `gitlab_token` parameter is set to a Personal Access Token \(PAT\) that is tied to a GitLab account that accesses the RHDH GitLab repositories. The default value can be set by setting the `default` field:

```yaml
- default: '<gitlab_pat>'
  description: |
    GitLab Personal Access Token
  name: gitlab_token
  type: string
```

##### Step 3.3: Set GitHub Webhook Secret Default Value

The `pipelines_webhook_secret` parameter is set to an user set secret string that is tied to a GitHub Webhook that points to the Pipelines as Code service on the OpenShift cluster. The default value can be set by setting the `default` field:

```yaml
- default: '<github_webhook_secret>'
  description: |
    Pipelines as Code webhook secret
  name: pipelines_webhook_secret
  type: string
```

##### Step 3.4: Set Quay DockerConfig JSON Default Value

The `quay_dockerconfigjson` parameter is set to the Quay DockerConfig JSON with an authentication string for logging into a Quay account that has access to the RHDH target image registries. The default value can be set by setting the `default` field:

```yaml
- default: '<quay_authentication_json>'
  description: |
    Image registry token
  name: quay_dockerconfigjson
  type: string
```

##### Step 3.5: Fetch the Cosign Signing Public Key

For setting the script, you will need to get the cosign signing public key from the `signing-secrets` Secret under the `openshift-pipelines` namespace by running the following:

```sh
kubectl get secrets -n openshift-pipelines signing-secrets -o jsonpath='{.data.cosign\.pub}'
```

**Note:** Keep the returned public key for the next step.

##### Step 3.6: Set the Task Script

Set the `.spec.steps[0].script` to the following script and replace the `<cosign_signing_public_key>` with the fetched cosign signing public key you fetched earlier:

```yaml
spec:
  ...
  steps:
    - ...
      name: setup
      script: |
        set -o errexit
        set -o nounset
        set -o pipefail

        SECRET_NAME="cosign-pub"
        if [ -n "<cosign_signing_public_key>" ]; then
          echo -n "* $SECRET_NAME secret: "
          cat <<EOF | kubectl apply -f - >/dev/null
        apiVersion: v1
        data:
          cosign.pub: <cosign_signing_public_key>
        kind: Secret
        metadata:
        labels:
          app.kubernetes.io/instance: default
          app.kubernetes.io/part-of: tekton-chains
          operator.tekton.dev/operand-name: tektoncd-chains
        name: $SECRET_NAME
        type: Opaque
        EOF
          echo "OK"
        fi

        SECRET_NAME="gitlab-auth-secret"
        if [ -n "$GITLAB_TOKEN" ]; then
          echo -n "* $SECRET_NAME secret: "
          kubectl create secret generic "$SECRET_NAME" \
            --from-literal=password=$GITLAB_TOKEN \
            --from-literal=username=oauth2 \
            --type=kubernetes.io/basic-auth \
            --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
          echo "OK"
        fi

        SECRET_NAME="gitops-auth-secret"
        if [ -n "$GIT_TOKEN" ]; then
          echo -n "* $SECRET_NAME secret: "
          kubectl create secret generic "$SECRET_NAME" \
            --from-literal=password=$GIT_TOKEN \
            --type=kubernetes.io/basic-auth \
            --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
          echo "OK"
        fi

        SECRET_NAME="pipelines-secret"
        if [ -n "$PIPELINES_WEBHOOK_SECRET" ]; then
          echo -n "* $SECRET_NAME secret: "
          kubectl create secret generic "$SECRET_NAME" \
            --from-literal=webhook.secret=$PIPELINES_WEBHOOK_SECRET \
            --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
          echo "OK"
        fi

        SECRET_NAME="rhdh-image-registry-token"
        if [ -n "$QUAY_DOCKERCONFIGJSON" ]; then
          echo -n "* $SECRET_NAME secret: "
          DATA=$(mktemp)
          echo -n "$QUAY_DOCKERCONFIGJSON" >"$DATA"
          kubectl create secret docker-registry "$SECRET_NAME" \
            --from-file=.dockerconfigjson="$DATA" --dry-run=client -o yaml | \
            kubectl apply --filename - --overwrite=true >/dev/null
          rm "$DATA"
          echo -n "."
          while ! kubectl get serviceaccount pipeline >/dev/null &>2; do
            sleep 2
            echo -n "_"
          done
          for SA in default pipeline; do
            kubectl patch serviceaccounts "$SA" --patch "
          secrets:
            - name: $SECRET_NAME
          imagePullSecrets:
            - name: $SECRET_NAME
          " >/dev/null
            echo -n "."
          done
          echo "OK"
        fi"
```

See the following optional steps for more information about each secret being created in this Task:
1. [Setting Up Gitops Authentication Secret Under Deployment Namespaces](#step-6-setting-up-gitops-authentication-secret-under-deployment-namespaces-optional)
2. [Setting Up Pipelines Secret Under Deployment Namespaces](#step-7-setting-up-pipelines-secret-under-deployment-namespaces-optional)
3. [Setting Up Quay Image Registry Secret Under Deployment Namespaces](#step-8-setting-up-quay-image-registry-secret-under-deployment-namespaces-optional)

#### Step 4: Setting Up Deployment Namespaces \(Optional\)

You can create the namespaces for different app deployments, this will mirror some the steps for the Tekton Task created. You will need a namespace for each kind of the deployment: development, staging, and production. These namespaces would follow a naming pattern of `<rhdh_namespace>-app-<deployment_kind>` with the target RHDH namespace as the prefix, therefore `$NAMESPACE-app-development`, `$NAMESPACE-app-stage`, and `$NAMESPACE-app-prod`. These namespaces can be created using the following:

```sh
APP_NAMESPACE=$NAMESPACE-app-<developer|stage|prod>
cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Namespace
metadata:
  labels:
    argocd.argoproj.io/managed-by: $NAMESPACE
  name: $APP_NAMESPACE
EOF
```

#### Step 5: Setting Up Cosign Secret Under Deployment Namespaces \(Optional\)

First you will need to fetch the cosign public key from the `signing-secrets` Secret in the `openshift-pipelines` namespace that was setup by the installer:

```sh
kubectl get secrets -n openshift-pipelines signing-secrets -o jsonpath='{.data.cosign\.pub}' 2>/dev/null
```

Take note of the public key, then use it to create the cosign secret under each of the deployment namespaces:

```sh
cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
data:
    cosign.pub: <cosign_public_key>
kind: Secret
metadata:
    labels:
        app.kubernetes.io/instance: default
        app.kubernetes.io/part-of: tekton-chains
        operator.tekton.dev/operand-name: tektoncd-chains
    name: cosign-pub
    namespace: $APP_NAMESPACE
type: Opaque
EOF
```

#### Step 6: Setting Up Gitops Authentication Secret Under Deployment Namespaces \(Optional\)

If you are using GitLab, you will need to create the GitLab authentication secret with your GitLab PAT as follows:

```sh
kubectl -n $APP_NAMESPACE create secret generic "gitlab-auth-secret" \
    --from-literal=password=<gitlab_pat> \
    --from-literal=username=oauth2 \
    --type=kubernetes.io/basic-auth \
    --dry-run=client -o yaml | kubectl -n $APP_NAMESPACE apply --filename - --overwrite=true >/dev/null
```

More information about GitLab authentication and GitLab PATs can be found under the [Pipelines as Code with GitLab documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_pipelines/1.15/html/pipelines_as_code/using-pipelines-as-code-repos#using-pipelines-as-code-with-gitlab_using-pipelines-as-code-repos).

Otherwise, you will need to create a Git authentication secret with your PAT (e.g. GitHub PAT) as follows:

```sh
kubectl -n $APP_NAMESPACE create secret generic "gitops-auth-secret" \
    --from-literal=password=<git_pat> \
    --type=kubernetes.io/basic-auth \
    --dry-run=client -o yaml | kubectl -n $APP_NAMESPACE apply --filename - --overwrite=true >/dev/null
```

**Note**: For GitHub PATs, you will need to set permissions which are highlighted under the [Pipelines as Code with GitHub documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_pipelines/1.15/html/pipelines_as_code/using-pipelines-as-code-repos#using-pipelines-as-code-with-github-webhook_using-pipelines-as-code-repos).

#### Step 7: Setting Up Pipelines Secret Under Deployment Namespaces \(Optional\)

You will need to create a pipeline secret containing the webhook secret for the Git organization for deployments to have proper access via the tekton pipelines:

```sh
kubectl -n $APP_NAMESPACE create secret generic "pipelines-secret" \
    --from-literal=webhook.secret=<webhook_secret> \
    --dry-run=client -o yaml | kubectl -n $APP_NAMESPACE apply --filename - --overwrite=true >/dev/null
```

#### Step 8: Setting Up Quay Image Registry Secret Under Deployment Namespaces \(Optional\)

For accessing the Quay image registry, you'll need to create a secret to store the docker config json file with authentication credentials you can obtain from your [quay.io](https://quay.io) account:

```sh
kubectl -n $APP_NAMESPACE create secret docker-registry "rhdh-image-registry-token" \
    --from-file=.dockerconfigjson="<dockerconfig_jsonfile>" --dry-run=client -o yaml | \
    kubectl -n $APP_NAMESPACE apply --filename - --overwrite=true >/dev/null
```

Then for both the `default` and `pipeline` service accounts under the deployment namespace, you will need to tie in the image registry secret you just created:

```sh
kubectl -n $APP_NAMESPACE patch serviceaccounts "<default|pipeline>" --patch "
secrets:
- name: rhdh-image-registry-token
imagePullSecrets:
- name: rhdh-image-registry-token
" >/dev/null
```