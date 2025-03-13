## Pre-Existing Red Hat Developer Hub Configuration

> [!IMPORTANT] 
> Currently support for pre-existing Red Hat Developer Hub instances is a work-in-progress (WIP)

### Prerequisites

- Performed steps under both [GitOps/ArgoCD Configuration](../GITOPS-CONFIG.md) and [Pipelines/Tekton Configuration](../PIPELINES-CONFIG.md)

### Script Configuration

Please ensure you have the following information related to your pre-existing instance available to use with our configuration script:
1. Namespace of RHDH & ArgoCD instance
2. Deployment name of RHDH
3. ConfigMap name for your RHDH plugins
   1. Typically `dynamic-plugins`
4. (If applicable) Secret name for your RHDH environment variables
   1. Only if bringing your own, if left blank or unset the script will create a new one

You are able to store these values in environment variables. Set the following the use environment variables:
- `EXISTING_NAMESPACE`
  - Name of target RHDH namespace
- `EXISTING_DEPLOYMENT`
  - Name of target RHDH deployment
- `RHDH_PLUGINS`
  - Name of the dynamic plugins ConfigMap
- `EXISTING_EXTRA_ENV_SECRET`
  - Name of the extra environment variables Secret

If using a [RHDH Operator](https://github.com/redhat-developer/rhdh-operator) instance the following required fields will be missing **by default (unless already setup)**:
- `.app.baseUrl`
- `.backend.baseUrl`
- `.backend.cors.origin`

You will need to ensure the above fields are set to the Developer Hub entrypoint URL. For example:

```yaml
data:
  app-config.base.yaml: |
    app:
      title: "Red Hat Developer Hub for AI Software Templates"
      baseUrl: https://backstage-ai-rh-developer-hub-ai-rhdh.apps.example-cluster.devcluster.openshift.com
    backend:
      baseUrl: https://backstage-ai-rh-developer-hub-ai-rhdh.apps.example-cluster.devcluster.openshift.com
      cors:
        origin: https://backstage-ai-rh-developer-hub-ai-rhdh.apps.example-cluster.devcluster.openshift.com
```

**Note**: Having these fields set under any app config ConfigMap tied to the existing RHDH instance should work. See [Configuring the Developer Hub Custom Resource](https://docs.redhat.com/en/documentation/red_hat_developer_hub/1.2/html/administration_guide_for_red_hat_developer_hub/assembly-add-custom-app-file-openshift_admin-rhdh#proc-add-custom-app-config-file-ocp-operator_admin-rhdh) for further details about setting up the RHDH app config.

For GitHub integration, run:
```
export RHDH_GITHUB_INTEGRATION=true
```

For GitLab integration, run:
```
export RHDH_GITLAB_INTEGRATION=true
```

**Note:** If both GitHub and GitLab integrations are enabled, you will be prompted to choose *one*.

Once you have done the prior steps and have the information from the prior steps readily available you can follow:

1. Run `export RHDH_INSTANCE_PROVIDED=true`
2. Run `bash ./scripts/configure-dh.sh` and follow the prompts in the command line

### Manual Configuration

#### Step 1: Create Kubernetes Service Account and Token

You can skip this step if these resources are already present in your desired namespace.

**Note:** If the resources are already present in your desired namespace, you will need to ensure that `$KUBERNETES_SA` and `$KUBERNETES_SA_TOKEN_SECRET` environment variables are set to the correct values.

```
export KUBERNETES_SA=<your-sa-name>
export KUBERNETES_SA_TOKEN_SECRET=<your-secret-name>
```

For information related to creating these resources see [`KUBERNETES_SERVICEACCOUNT.md`](../pipelines/KUBERNETES_SERVICEACCOUNT.md).

#### Step 2: Create Extra Environment Variables Secret

**Note:** The following commands assume that `export KUBERNETES_SA_TOKEN_SECRET=<your-secret-name>` and `export KUBERNETES_SA=<your-sa-name>` were run.

You will need to create a Secret to store all the private environment variables for RHDH. This can be done one of the following ways:

**No Integration**

```sh
K8S_SA_SECRET_NAME=$(kubectl get secrets -n "$NAMESPACE" -o name | grep "$KUBERNETES_SA_TOKEN_SECRET" | cut -d/ -f2 | head -1)
K8S_SA_TOKEN=$(kubectl -n $NAMESPACE get secret $K8S_SA_SECRET_NAME -o yaml | yq '.data.token' -M -I=0)
KUBERNETES_SA_ENCODED=$(echo -n "$KUBERNETES_SA" | base64 -w 0)
kubectl -n $NAMESPACE create secret generic ai-rh-developer-hub-env \
    --from-literal=NODE_TLS_REJECT_UNAUTHORIZED=$(echo "0" | base64) \
    --from-literal=K8S_SA_TOKEN=${K8S_SA_TOKEN} \
    --from-literal=K8S_SA=${KUBERNETES_SA_ENCODED}
```

**GitHub**

```sh
K8S_SA_SECRET_NAME=$(kubectl get secrets -n "$NAMESPACE" -o name | grep "$KUBERNETES_SA_TOKEN_SECRET" | cut -d/ -f2 | head -1)
K8S_SA_TOKEN=$(kubectl -n $NAMESPACE get secret $K8S_SA_SECRET_NAME -o yaml | yq '.data.token' -M -I=0)
KUBERNETES_SA_ENCODED=$(echo -n "$KUBERNETES_SA" | base64 -w 0)
kubectl -n $NAMESPACE create secret generic ai-rh-developer-hub-env \
    --from-literal=NODE_TLS_REJECT_UNAUTHORIZED=$(echo "0" | base64) \
    --from-literal=K8S_SA_TOKEN=${K8S_SA_TOKEN} \
    --from-literal=GITHUB__APP__ID=$(echo '<github_app_id>' | base64) \
    --from-literal=GITHUB__APP__CLIENT__ID=$(echo '<github_app_client_id>' | base64) \
    --from-literal=GITHUB__APP__CLIENT__SECRET=$(echo '<github_app_client_secret>' | base64) \
    --from-literal=GITHUB__APP__WEBHOOK__URL=$(echo '<github_app_webhook_url>' | base64) \
    --from-literal=GITHUB__APP__WEBHOOK__SECRET=$(echo '<github_app_webhook_secret>' | base64) \
    --from-file=GITHUB__APP__PRIVATE_KEY='<path-to-app-pk>' \
    --from-literal=GITHUB__ORG__NAME=$(echo '<github_org_name>' | base64) \
    --from-literal=GITOPS__GIT_TOKEN=$(echo '<git_pat>' | base64) \
    --from-literal=K8S_SA=${KUBERNETES_SA_ENCODED}
```

**GitHub Enterprise**

```sh
K8S_SA_SECRET_NAME=$(kubectl get secrets -n "$NAMESPACE" -o name | grep "$KUBERNETES_SA_TOKEN_SECRET" | cut -d/ -f2 | head -1)
K8S_SA_TOKEN=$(kubectl -n $NAMESPACE get secret $K8S_SA_SECRET_NAME -o yaml | yq '.data.token' -M -I=0)
KUBERNETES_SA_ENCODED=$(echo -n "$KUBERNETES_SA" | base64 -w 0)
kubectl -n $NAMESPACE create secret generic ai-rh-developer-hub-env \
    --from-literal=NODE_TLS_REJECT_UNAUTHORIZED=$(echo "0" | base64) \
    --from-literal=K8S_SA_TOKEN=${K8S_SA_TOKEN} \
    --from-literal=GITHUB__APP__ID=$(echo '<github_app_id>' | base64) \
    --from-literal=GITHUB__APP__CLIENT__ID=$(echo '<github_app_client_id>' | base64) \
    --from-literal=GITHUB__APP__CLIENT__SECRET=$(echo '<github_app_client_secret>' | base64) \
    --from-literal=GITHUB__APP__WEBHOOK__URL=$(echo '<github_app_webhook_url>' | base64) \
    --from-literal=GITHUB__APP__WEBHOOK__SECRET=$(echo '<github_app_webhook_secret>' | base64) \
    --from-file=GITHUB__APP__PRIVATE_KEY='<path-to-app-pk>' \
    --from-literal=GITHUB__HOST=$(echo '<github_hostname>' | base64) \
    --from-literal=GITHUB__ORG__NAME=$(echo '<github_org_name>' | base64) \
    --from-literal=GITOPS__GIT_TOKEN=$(echo '<git_pat>' | base64) \
    --from-literal=K8S_SA=${KUBERNETES_SA_ENCODED}
```

**GitLab**

```sh
K8S_SA_SECRET_NAME=$(kubectl get secrets -n "$NAMESPACE" -o name | grep "$KUBERNETES_SA_TOKEN_SECRET" | cut -d/ -f2 | head -1)
K8S_SA_TOKEN=$(kubectl -n $NAMESPACE get secret $K8S_SA_SECRET_NAME -o yaml | yq '.data.token' -M -I=0)
KUBERNETES_SA_ENCODED=$(echo -n "$KUBERNETES_SA" | base64 -w 0)
kubectl -n $NAMESPACE create secret generic ai-rh-developer-hub-env \
    --from-literal=NODE_TLS_REJECT_UNAUTHORIZED=$(echo "0" | base64) \
    --from-literal=K8S_SA_TOKEN=${K8S_SA_TOKEN} \
    --from-literal=GITLAB__APP__CLIENT__ID=$(echo '<gitlab_app_client_id>' | base64) \
    --from-literal=GITLAB__APP__CLIENT__SECRET=$(echo '<gitlab_app_client_secret>' | base64) \
    --from-literal=GITLAB__TOKEN=$(echo '<gitlab_pat>' | base64) \
    --from-literal=GITLAB__GROUP__NAME=$(echo '<gitlab_group_name>' | base64) \
    --from-literal=K8S_SA=${KUBERNETES_SA_ENCODED}
```

**Note:** When targeting the community hosted GitLab (gitlab.com), the `GITLAB__ORG__ENABLED` variable will be ignored as gitlab.com has organizations enabled always as specified in the [backstage docs](https://backstage.io/docs/integrations/gitlab/org#users).

**GitLab Self-hosted**

```sh
K8S_SA_SECRET_NAME=$(kubectl get secrets -n "$NAMESPACE" -o name | grep "$KUBERNETES_SA_TOKEN_SECRET" | cut -d/ -f2 | head -1)
K8S_SA_TOKEN=$(kubectl -n $NAMESPACE get secret $K8S_SA_SECRET_NAME -o yaml | yq '.data.token' -M -I=0)
KUBERNETES_SA_ENCODED=$(echo -n "$KUBERNETES_SA" | base64 -w 0)
kubectl -n $NAMESPACE create secret generic ai-rh-developer-hub-env \
    --from-literal=NODE_TLS_REJECT_UNAUTHORIZED=$(echo "0" | base64) \
    --from-literal=K8S_SA_TOKEN=${K8S_SA_TOKEN} \
    --from-literal=GITLAB__APP__CLIENT__ID=$(echo '<gitlab_app_client_id>' | base64) \
    --from-literal=GITLAB__APP__CLIENT__SECRET=$(echo '<gitlab_app_client_secret>' | base64) \
    --from-literal=GITLAB__TOKEN=$(echo '<gitlab_pat>' | base64) \
    --from-literal=GITLAB__HOST=$(echo '<gitlab_hostname>' | base64) \
    --from-literal=GITLAB__HOST=$(echo '<gitlab_hostname>' | base64) \
    --from-literal=GITLAB__GROUP__NAME=$(echo '<gitlab_group_name>' | base64) \
    --from-literal=GITLAB__ORG__ENABLED=$(echo '<true|false>' | base64) \
    --from-literal=K8S_SA=${KUBERNETES_SA_ENCODED}
```

**GitHub & GitLab**

```sh
K8S_SA_SECRET_NAME=$(kubectl get secrets -n "$NAMESPACE" -o name | grep "$KUBERNETES_SA_TOKEN_SECRET" | cut -d/ -f2 | head -1)
K8S_SA_TOKEN=$(kubectl -n $NAMESPACE get secret $K8S_SA_SECRET_NAME -o yaml | yq '.data.token' -M -I=0)
KUBERNETES_SA_ENCODED=$(echo -n "$KUBERNETES_SA" | base64 -w 0)
kubectl -n $NAMESPACE create secret generic ai-rh-developer-hub-env \
    --from-literal=NODE_TLS_REJECT_UNAUTHORIZED=$(echo "0" | base64) \
    --from-literal=K8S_SA_TOKEN=${K8S_SA_TOKEN} \
    --from-literal=GITHUB__APP__ID=$(echo '<github_app_id>' | base64) \
    --from-literal=GITHUB__APP__CLIENT__ID=$(echo '<github_app_client_id>' | base64) \
    --from-literal=GITHUB__APP__CLIENT__SECRET=$(echo '<github_app_client_secret>' | base64) \
    --from-literal=GITHUB__APP__WEBHOOK__URL=$(echo '<github_app_webhook_url>' | base64) \
    --from-literal=GITHUB__APP__WEBHOOK__SECRET=$(echo '<github_app_webhook_secret>' | base64) \
    --from-file=GITHUB__APP__PRIVATE_KEY='<path-to-app-pk>' \
    --from-literal=GITHUB__ORG__NAME=$(echo '<github_org_name>' | base64) \
    --from-literal=GITOPS__GIT_TOKEN=$(echo '<git_pat>' | base64) \
    --from-literal=GITLAB__APP__CLIENT__ID=$(echo '<gitlab_app_client_id>' | base64) \
    --from-literal=GITLAB__APP__CLIENT__SECRET=$(echo '<gitlab_app_client_secret>' | base64) \
    --from-literal=GITLAB__TOKEN=$(echo '<gitlab_pat>' | base64) \
    --from-literal=GITLAB__GROUP__NAME=$(echo '<gitlab_group_name>' | base64) \
    --from-literal=K8S_SA=${KUBERNETES_SA_ENCODED}
```

Notice that `K8S_SA_TOKEN` does not need encoding as the other literal sets, this is because when the value is fetched from the Service Account Token Secret it comes back already encoded.

#### Step 3: Setting the Extra Environment Variables Secret to Developer Hub

You will need to set up your Developer Hub instance to use the Extra Environment Variables Secret you created. To do this you will need to patch the Secret into the deployment by doing either of the following:

**RHDH Operator Deployments**

```sh
kubectl get backstage <backstage-cr-name> -n $NAMESPACE -o yaml | \
  yq '.spec.application.extraEnvs.secrets += [{"name": "ai-rh-developer-hub-env"}] | 
  .spec.application.extraEnvs.secrets |= unique_by(.name)' | \
  kubectl apply -f -
```

**Other RHDH Deployments**

```sh
kubectl get deploy <rhdh-deployment-name> -n $NAMESPACE -o yaml | \
  yq '.spec.template.spec.containers[0].envFrom += [{"secretRef": {"name": "ai-rh-developer-hub-env"}}] |
  .spec.template.spec.containers[0].envFrom |= unique_by(.secretRef.name)' | \
  kubectl apply -f -
```

#### Step 4: Create the Extra App Config ConfigMap

Follow the same steps under [step 3 for the ai-rhdh-installer](./INSTALLER-PROVISIONED.md#step-3-create-the-extra-app-config-configmap).

#### Step 5: Setting the Extra App Config to Developer Hub

Similar to [step 4 for the ai-rhdh-installer](./INSTALLER-PROVISIONED.md#step-4-setting-the-extra-app-config-to-developer-hub), you will need to set up your Developer Hub instance to use the Extra App Config you created. To do this you will need to patch the app config into the deployment spec:

```sh
kubectl get deploy <rhdh-deployment-name> -n $NAMESPACE -o yaml | \
  yq '.spec.template.spec.volumes += {"name": "developer-hub-app-config", "configMap": {"name": "developer-hub-app-config", "defaultMode": 420, "optional": false}} | 
  .spec.template.spec.containers[0].volumeMounts += {"name": "developer-hub-app-config", "readOnly": true, "mountPath": "/opt/app-root/src/app-config.extra.yaml", "subPath": "app-config.extra.yaml"} |
  .spec.template.spec.containers[0].args += ["--config", "/opt/app-root/src/app-config.extra.yaml"]' | \
  kubectl apply -f -
```

**Note**: If you are bringing your own [RHDH Operator](https://github.com/redhat-developer/rhdh-operator) instance, you can follow [step 3 for the ai-rhdh-installer](./INSTALLER-PROVISIONED.md#step-3-setting-the-extra-app-config-to-developer-hub) instead.

#### Step 6: Updating ArgoCD Plugins

Follow the same steps under either [step 6.1](./INSTALLER-PROVISIONED.md#step-61-updating-argocd-plugins-via-web-console) or [step 6.2](./INSTALLER-PROVISIONED.md#step-62-updating-argocd-plugins-via-cli) for the ai-rhdh-installer.

#### Step 7: Updating Tekton Plugins

Follow the same steps under either [step 7.1](./INSTALLER-PROVISIONED.md#step-71-updating-tekton-plugins-via-web-console) or [step 7.2](./INSTALLER-PROVISIONED.md#step-72-updating-tekton-plugins-via-cli) for the ai-rhdh-installer.

#### Step 8: Updating Developer Hub Plugins

Follow the same steps under either [step 8.1](./INSTALLER-PROVISIONED.md#step-81-updating-developer-hub-plugins-via-web-console) or [step 8.2](./INSTALLER-PROVISIONED.md#step-82-updating-developer-hub-plugins-via-cli) for the ai-rhdh-installer.

#### Step 9: Updating RHDH Deployment with ArgoCD Resources

Now you will need to make sure that all of the ArgoCD tied resources are setup with the Developer Hub deployment. Run the following to attach the ArgoCD ConfigMap and Secret:

```sh
kubectl get deploy <rhdh-deployment-name> -n $NAMESPACE -o yaml | \
  yq '.spec.template.spec.volumes += [{"name": "argocd-config", "configMap": {"name": "argocd-config", "defaultMode": 420, "optional": false}}] |
  .spec.template.spec.containers[0].envFrom += [{"secretRef": {"name": "rhdh-argocd-secret"}}] |
  .spec.template.spec.containers[0].volumeMounts += [{"name": "argocd-config", "readOnly": true, "mountPath": "/opt/app-root/src/argocd-config.yaml", "subPath": "argocd-config.yaml"}] |
  .spec.template.spec.containers[0].args += ["--config", "/opt/app-root/src/argocd-config.yaml"]' | \
  kubectl apply -f -
```

**Note**: If you are bringing your own [RHDH Operator](https://github.com/redhat-developer/rhdh-operator) instance, you can follow [step 9.2 for the ai-rhdh-installer](./INSTALLER-PROVISIONED.md#step-92-argocd-config-and-secret) instead.