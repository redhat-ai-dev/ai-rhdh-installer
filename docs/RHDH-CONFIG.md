## Developer Hub Configuration

As part of this section you will find information about the following configuration methods:

1. [Configuring Developer Hub with the configuration script after using our `ai-rhdh-installer`](#ai-rhdh-installer-script-configuration)
2. [Configuring Developer Hub manually after using our `ai-rhdh-installer`](#ai-rhdh-installer-manual-configuration)
3. [Configuring Developer Hub with the configuration script for a pre-existing Red Hat Developer Hub instance](#pre-existing-instance-script-configuration)
4. [Configuring Developer Hub manually for a pre-existing Red Hat Developer Hub instance](#pre-existing-instance-manual-configuration)

### Prerequisites

- Performed steps under both [GitOps/ArgoCD Configuration](GITOPS-CONFIG.md) and [Pipelines/Tekton Configuration](PIPELINES-CONFIG.md)
- [yq](https://github.com/mikefarah/yq/) version 4.0+
- [kubectl](https://github.com/kubernetes/kubectl) or [oc](https://docs.openshift.com/container-platform/4.16/cli_reference/openshift_cli/getting-started-cli.html) version compatible with your target cluster

### AI-RHDH-Installer: Script Configuration
If you installed using the [`ai-rhdh-installer`](../README.md#install) all that is required for setting up the RHDH instance is to run `bash ./scripts/configure-dh.sh`. Please note if you changed the installation namespace used by the installer you will first need to run `export NAMESPACE=<namespace used>` as the default value is `ai-rhdh`. 

If you are planning to use GitHub integration run `export RHDH_GITHUB_INTEGRATION=true` and to use GitLab integration run `export RHDH_GITLAB_INTEGRATION=true`. 

**Note**: Ensure that you have all secret variables tied to the enabled integrations set:

**GitHub**
- `GITHUB__APP__ID`
- `GITHUB__APP__CLIENT__ID`
- `GITHUB__APP__CLIENT__SECRET`
- `GITHUB__APP__WEBHOOK__URL`
- `GITHUB__APP__WEBHOOK__SECRET`
- `GITHUB__APP__PRIVATE_KEY`
- `GITOPS__GIT_TOKEN`

**GitLab**
- `GITLAB__APP__CLIENT__ID`
- `GITLAB__APP__CLIENT__SECRET`
- `GITLAB__TOKEN`

### AI-RHDH-Installer: Manual Configuration

The installer will create the following resources to use:
- [`secret/ai-rh-developer-hub-env`](../chart/templates/developer-hub/includes/_extra-env.tpl) - A Secret which stores all the developer hub private variables
- [`configmap/developer-hub-base-app-config`](../chart/templates/developer-hub/includes/_appconfig.tpl) - A ConfigMap that contains the base config for developer hub, such as the site url fields
- [`configmap/dynamic-plugins`](../chart/templates/developer-hub/includes/_plugins.tpl) - A ConfigMap that contains the list of enabled plugins for developer hub to install and use
- [`backstage/ai-rh-developer-hub`](../chart/templates/developer-hub/includes/_backstage.tpl) - A CR for controlling the developer hub deployment

#### Step 1: Patch the Extra Environment Variables Secret

You will need to patch the `ai-rh-developer-hub-env` Secret set all the private environment variables for RHDH. This can be done one of the following ways:

**GitHub**

```sh
kubectl -n $NAMESPACE patch secret ai-rh-developer-hub-env \
    --type 'merge' \
    -p="{\"data\": {\"GITHUB__APP__ID\": \"$(echo '<github_app_id>' | base64)\",
    \"GITHUB__APP__CLIENT__ID\": \"$(echo '<github_app_client_id>' | base64)\",
    \"GITHUB__APP__CLIENT__SECRET\": \"$(echo '<github_app_client_secret>' | base64)\",
    \"GITHUB__APP__WEBHOOK__URL\": \"$(echo '<github_app_webhook_url>' | base64)\",
    \"GITHUB__APP__WEBHOOK__SECRET\": \"$(echo '<github_app_webhook_secret>' | base64)\",
    \"GITHUB__APP__PRIVATE_KEY\": \"$(base64 '</path/to/app/pk>')\",
    \"GITOPS__GIT_TOKEN\": \"$(echo '<git_pat>' | base64)\"}}"
```

**GitLab**

```sh
kubectl -n $NAMESPACE patch secret ai-rh-developer-hub-env \
    --type 'merge' \
    -p="{\"data\": {\"GITLAB__APP__CLIENT__ID\": \"$(echo '<gitlab_app_client_id>' | base64)\",
    \"GITLAB__APP__CLIENT__SECRET\": \"$(echo '<gitlab_app_client_secret>' | base64)\",
    \"GITLAB__TOKEN\": \"$(echo '<gitlab_pat>' | base64)\"}}"
```

**Both**

```sh
kubectl -n $NAMESPACE patch secret ai-rh-developer-hub-env \
    --type 'merge' \
    -p="{\"data\": {\"GITHUB__APP__ID\": \"$(echo '<github_app_id>' | base64)\",
    \"GITHUB__APP__CLIENT__ID\": \"$(echo '<github_app_client_id>' | base64)\",
    \"GITHUB__APP__CLIENT__SECRET\": \"$(echo '<github_app_client_secret>' | base64)\",
    \"GITHUB__APP__WEBHOOK__URL\": \"$(echo '<github_app_webhook_url>' | base64)\",
    \"GITHUB__APP__WEBHOOK__SECRET\": \"$(echo '<github_app_webhook_secret>' | base64)\",
    \"GITHUB__APP__PRIVATE_KEY\": \"$(base64 '</path/to/app/pk>')\",
    \"GITOPS__GIT_TOKEN\": \"$(echo '<git_pat>' | base64)\",
    \"GITLAB__APP__CLIENT__ID\": \"$(echo '<gitlab_app_client_id>' | base64)\",
    \"GITLAB__APP__CLIENT__SECRET\": \"$(echo '<gitlab_app_client_secret>' | base64)\",
    \"GITLAB__TOKEN\": \"$(echo '<gitlab_pat>' | base64)\"}}""
```

#### Step 2: Create the Extra App Config ConfigMap

The base app config only contains what is needed to run developer hub at a workable default setting state. To customize developer hub for our purposes, we will need to create a ConfigMap for extra app configuration of the developer hub instance. 

Notice that [developer-hub-app-config.yaml](../resources/developer-hub-app-config.yaml) contains the starting point of this app config, we will need to add more pieces to it depending on the integration we want.

##### Step 2.1: GitHub Integration

For enabling GitHub for authentication you will need to add the following under `.auth` within the app config:

```yaml
providers:
  github:
    production:
      clientId: ${GITHUB__APP__CLIENT__ID}
      clientSecret: ${GITHUB__APP__CLIENT__SECRET}
```

For enabling GitHub integration you will need to add the following under the root of the app config:

```yaml
integrations:
  github:
    - host: github.com
      apps:
        - appId: ${GITHUB__APP__ID}
          clientId: ${GITHUB__APP__CLIENT__ID}
          clientSecret: ${GITHUB__APP__CLIENT__SECRET}
          webhookUrl: ${GITHUB__APP__WEBHOOK__URL}
          webhookSecret: ${GITHUB__APP__WEBHOOK__SECRET}
          privateKey: ${GITHUB__APP__PRIVATE_KEY}
```

When you are ready to apply changes run the following command:

```sh
kubectl -n $NAMESPACE apply -f resources/developer-hub-app-config.yaml
```

##### Step 2.2: GitLab Integration

For enabling GitLab for authentication you will need to add the following under `.auth` within the app config:

```yaml
providers:
  gitlab:
    production:
      clientId: ${GITLAB__APP__CLIENT__ID}
      clientSecret: ${GITLAB__APP__CLIENT__SECRET}
```

For enabling GitLab integration you will need to add the following under the root of the app config:

```yaml
integrations:
  gitlab:
    - host: github.com
      token: ${GITLAB__TOKEN}
```

When you are ready to apply changes run the following command:

```sh
kubectl -n $NAMESPACE apply -f resources/developer-hub-app-config.yaml
```

#### Step 3: Setting the Extra App Config to Developer Hub

Now that the extra app config ConfigMap has been created, you will need to set up your developer hub instance to use it. To do this you will need to patch the app config into the deployment's `Backstage` CR:

```sh
kubectl -n $NAMESPACE get backstage ai-rh-developer-hub -o yaml | \
        yq '.spec.application.appConfig.configMaps += [{"name": "developer-hub-app-config"}] | 
            .spec.application.appConfig.configMaps |= unique_by(.name)' -M -I=0 -o=json | \
        kubectl apply -n $NAMESPACE -f -
```

#### Step 4.1: Updating ArgoCD Plugins Via Web Console
**Note: RHDH will encounter errors if the ArgoCD plugins are loaded before an instance is properly attached - This step may result in errors until all steps are completed**

To include the [ArgoCD plugins list](../dynamic-plugins/argocd-plugins.yaml) we need to edit the dynamic plugins ConfigMap that is attached to the RHDH instance:

![Dynamic Plugins Example](../assets/dynamic-plugins-example.png)

Edit the associated `yaml` file to include the contents of the [ArgoCD plugins list](../dynamic-plugins/argocd-plugins.yaml) under the `plugins` section:

![Dynamic Plugins Example 2](../assets/dynamic-plugins-example-2.png)

#### Step 4.2: Updating ArgoCD Plugins Via CLI

Alternatively, we can use this series of commands to perform the same task with `kubectl` and `yq` using the [`argocd-plugins.yaml`](../dynamic-plugins/argocd-plugins.yaml):

1. Fetch the dynamic plugins ConfigMap and save the `dynamic-plugins.yaml` content within to a temp file
    ```sh
    kubectl get configmap dynamic-plugins -n $NAMESPACE -o yaml | yq '.data["dynamic-plugins.yaml"]' > temp-dynamic-plugins.yaml
    ```
2. Merge the contents of [`argocd-plugins.yaml`](../dynamic-plugins/argocd-plugins.yaml) into the temp file
    ```sh
    yq -i ".plugins += $(yq '.plugins' ./dynamic-plugins/argocd-plugins.yaml -M -o json) | .plugins |= unique_by(.package)" temp-dynamic-plugins.yaml
    ```
3. Patch the dynamic plugins ConfigMap with the updated content in the temp file
    ```sh
    kubectl patch configmap dynamic-plugins -n $NAMESPACE \
    --type='merge' \
    -p="{\"data\":{\"dynamic-plugins.yaml\":\"$(echo "$(cat temp-dynamic-plugins.yaml)" | sed 's/"/\\"/g' | sed 's/$/\\n/g' | tr -d '\n')\"}}"
    ```
4. Dynamic plugins should be updated to include the [ArgoCD plugins list](../dynamic-plugins/argocd-plugins.yaml) with a pod update triggered and you may remove the temp file at this point

#### Step 5.1: Updating Tekton Plugins Via Web Console

To include the [Tekton plugins list](../dynamic-plugins/tekton-plugins.yaml) we need to edit the dynamic plugins ConfigMap that is attached to the RHDH instance:

![Dynamic Plugins Example](../assets/dynamic-plugins-example.png)

Edit the associated `yaml` file to include the contents of the [Tekton plugins list](../dynamic-plugins/tekton-plugins.yaml) under the `plugins` section:

![Dynamic Plugins Example 3](../assets/dynamic-plugins-example-3.png)

#### Step 5.2: Updating Tekton Plugins Via CLI

Alternatively, we can use this series of commands to perform the same task with `kubectl` and `yq` using the [`tekton-plugins.yaml`](../dynamic-plugins/tekton-plugins.yaml):

1. Fetch the dynamic plugins ConfigMap and save the `dynamic-plugins.yaml` content within to a temp file
    ```sh
    kubectl get configmap dynamic-plugins -n $NAMESPACE -o yaml | yq '.data["dynamic-plugins.yaml"]' > temp-dynamic-plugins.yaml
    ```
2. Merge the contents of [`tekton-plugins.yaml`](../dynamic-plugins/tekton-plugins.yaml) into the temp file
    ```sh
    yq -i ".plugins += $(yq '.plugins' ./dynamic-plugins/tekton-plugins.yaml -M -o json) | .plugins |= unique_by(.package)" temp-dynamic-plugins.yaml
    ```
3. Patch the dynamic plugins ConfigMap with the updated content in the temp file
    ```sh
    kubectl patch configmap dynamic-plugins -n $NAMESPACE \
    --type='merge' \
    -p="{\"data\":{\"dynamic-plugins.yaml\":\"$(echo "$(cat temp-dynamic-plugins.yaml)" | sed 's/"/\\"/g' | sed 's/$/\\n/g' | tr -d '\n')\"}}"
    ```
4. Dynamic plugins should be updated with the [Tekton plugins list](../dynamic-plugins/tekton-plugins.yaml) with a pod update triggered and you may remove the temp file at this point

#### Step 6.1: Updating Developer Hub Plugins Via Web Console

To include the [Developer Hub plugins list](../dynamic-plugins/dh-plugins.yaml) we need to edit the dynamic plugins ConfigMap that is attached to the RHDH instance:

![Dynamic Plugins Example](../assets/dynamic-plugins-example.png)

Edit the associated `yaml` file to include the contents of the [Developer Hub plugins list](../dynamic-plugins/dh-plugins.yaml) under the `plugins` section:

![Dynamic Plugins Example 4](../assets/dynamic-plugins-example-4.png)

#### Step 6.2: Updating Developer Hub Plugins Via CLI

Alternatively, we can use this series of commands to perform the same task with `kubectl` and `yq` using the [`dh-plugins.yaml`](../dynamic-plugins/dh-plugins.yaml):

1. Fetch the dynamic plugins ConfigMap and save the `dynamic-plugins.yaml` content within to a temp file
    ```sh
    kubectl get configmap dynamic-plugins -n $NAMESPACE -o yaml | yq '.data["dynamic-plugins.yaml"]' > temp-dynamic-plugins.yaml
    ```
2. Merge the contents of [`dh-plugins.yaml`](../dynamic-plugins/dh-plugins.yaml) into the temp file
    ```sh
    yq -i ".plugins += $(yq '.plugins' ./dynamic-plugins/dh-plugins.yaml -M -o json) | .plugins |= unique_by(.package)" temp-dynamic-plugins.yaml
    ```
3. Patch the dynamic plugins ConfigMap with the updated content in the temp file
    ```sh
    kubectl patch configmap dynamic-plugins -n $NAMESPACE \
    --type='merge' \
    -p="{\"data\":{\"dynamic-plugins.yaml\":\"$(echo "$(cat temp-dynamic-plugins.yaml)" | sed 's/"/\\"/g' | sed 's/$/\\n/g' | tr -d '\n')\"}}"
    ```
4. Dynamic plugins should be updated with the [Developer Hub plugins list](../dynamic-plugins/dh-plugins.yaml) with a pod update triggered and you may remove the temp file at this point

#### Step 7: Updating RHDH Deployment

Now you will need to make sure that all of the ArgoCD and Tekton tied resources are setup with the developer hub deployment.

##### Step 7.1: Patch Kubernetes Service Account Token

Run the following to patch in the Kubernetes Service Account Token that is needed for use under the Kubernetes dynamic plugin:

```sh
K8S_SA_SECRET_NAME=$(kubectl get secrets -n "$NAMESPACE" -o name | grep rhdh-kubernetes-plugin-token- | cut -d/ -f2 | head -1)
K8S_SA_TOKEN=$(kubectl -n $NAMESPACE get secret $K8S_SA_SECRET_NAME -o yaml | yq '.data.token' -M -I=0)
kubectl -n $NAMESPACE patch secret ai-rh-developer-hub-env \
    --type 'merge' \
    -p="{\"data\": {\"K8S_SA_TOKEN\": \"${K8S_SA_TOKEN}\"}}"
```

Notice that `K8S_SA_TOKEN` does not need encoding as the other literal sets, this is because when the value is fetched from the service account token secret it comes back already encoded.

##### Step 7.2: ArgoCD Config and Secret

Run the following to attach the ArgoCD ConfigMap and Secret:

```sh
kubectl -n $NAMESPACE get backstage ai-rh-developer-hub -o yaml | \
        yq '.spec.application.appConfig.configMaps += [{"name": "argocd-config"}] | 
            .spec.application.appConfig.configMaps |= unique_by(.name) |
            .spec.application.extraEnvs.secrets += [{"name": "rhdh-argocd-secret"}] | 
            .spec.application.extraEnvs.secrets |= unique_by(.name)' -M -I=0 -o=json | \
        kubectl apply -n $NAMESPACE -f -
```

See [GitOps/ArgoCD Configuration](GITOPS-CONFIG.md#ai-rhdh-installer-manual-configuration) for information on creating the ArgoCD ConfigMap and Secret.

### Pre-Existing Instance: Script Configuration

For bringing a pre-existing instance to use with `configure-dh.sh`, ensure you gather the following information:
1. Namespace of RHDH & ArgoCD instance
2. Deployment name of RHDH
3. ConfigMap name for your RHDH plugins
   1. Typically `dynamic-plugins`
4. (If applicable) Secret name for your RHDH environment variables
   1. Only if bringing your own, if left blank or unset the script will create a new one

You are able to store these values in environment variables. Set the following the use environment variables:
- `$EXISTING_NAMESPACE`
  - Name of target RHDH namespace
- `$EXISTING_DEPLOYMENT`
  - Name of target RHDH deployment
- `$RHDH_PLUGINS`
  - Name of the dynamic plugins ConfigMap
- `$EXISTING_EXTRA_ENV_SECRET`
  - Name of the extra environment variables Secret

If using a [RHDH Operator](https://github.com/redhat-developer/rhdh-operator) instance the following required fields will be missing **by default (unless already setup)**:
- `.app.baseUrl`
- `.backend.baseUrl`
- `.backend.cors.origin`

You will need to ensure the above fields are set to the developer hub entrypoint url the tied app config. For example:

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

**Note**: Having these fields set under any app config ConfigMap tied to the existing RHDH instance should work. 

If you are planning to use GitHub integration run `export RHDH_GITHUB_INTEGRATION=true` and to use GitLab integration run `export RHDH_GITLAB_INTEGRATION=true`. 

**Note**: Ensure that you have all secret variables tied to the enabled integrations set:

**GitHub**
- `GITHUB__APP__ID`
- `GITHUB__APP__CLIENT__ID`
- `GITHUB__APP__CLIENT__SECRET`
- `GITHUB__APP__WEBHOOK__URL`
- `GITHUB__APP__WEBHOOK__SECRET`
- `GITHUB__APP__PRIVATE_KEY`
- `GITOPS__GIT_TOKEN`

**GitLab**
- `GITLAB__APP__CLIENT__ID`
- `GITLAB__APP__CLIENT__SECRET`
- `GITLAB__TOKEN`

Once you have done the prior steps and have the information from the prior steps readily available you can follow:

1. Run `export RHDH_INSTANCE_PROVIDED=true`
2. Run `bash ./scripts/configure-dh.sh` and follow the prompts in the command line

### Pre-Existing Instance: Manual Configuration

#### Step 1: Create Extra Environment Variables Secret

You will need to create a Secret to store all the private environment variables for RHDH. This can be done one of the following ways:

**No Integration**

```sh
K8S_SA_SECRET_NAME=$(kubectl get secrets -n "$NAMESPACE" -o name | grep rhdh-kubernetes-plugin-token- | cut -d/ -f2 | head -1)
K8S_SA_TOKEN=$(kubectl -n $NAMESPACE get secret $K8S_SA_SECRET_NAME -o yaml | yq '.data.token' -M -I=0)
kubectl -n $NAMESPACE create secret generic ai-rh-developer-hub-env \
    --from-literal=NODE_TLS_REJECT_UNAUTHORIZED=$(echo "0" | base64) \
    --from-literal=K8S_SA_TOKEN=${K8S_SA_TOKEN}
```

**GitHub**

```sh
K8S_SA_SECRET_NAME=$(kubectl get secrets -n "$NAMESPACE" -o name | grep rhdh-kubernetes-plugin-token- | cut -d/ -f2 | head -1)
K8S_SA_TOKEN=$(kubectl -n $NAMESPACE get secret $K8S_SA_SECRET_NAME -o yaml | yq '.data.token' -M -I=0)
kubectl -n $NAMESPACE create secret generic ai-rh-developer-hub-env \
    --from-literal=NODE_TLS_REJECT_UNAUTHORIZED=$(echo "0" | base64) \
    --from-literal=K8S_SA_TOKEN=${K8S_SA_TOKEN} \
    --from-literal=GITHUB__APP__ID=$(echo '<github_app_id>' | base64) \
    --from-literal=GITHUB__APP__CLIENT__ID=$(echo '<github_app_client_id>' | base64) \
    --from-literal=GITHUB__APP__CLIENT__SECRET=$(echo '<github_app_client_secret>' | base64) \
    --from-literal=GITHUB__APP__WEBHOOK__URL=$(echo '<github_app_webhook_url>' | base64) \
    --from-literal=GITHUB__APP__WEBHOOK__SECRET=$(echo '<github_app_webhook_secret>' | base64) \
    --from-file=GITHUB__APP__PRIVATE_KEY='<path-to-app-pk>' \
    --from-literal=GITOPS__GIT_TOKEN=$(echo '<git_pat>' | base64)
```

**GitLab**

```sh
K8S_SA_SECRET_NAME=$(kubectl get secrets -n "$NAMESPACE" -o name | grep rhdh-kubernetes-plugin-token- | cut -d/ -f2 | head -1)
K8S_SA_TOKEN=$(kubectl -n $NAMESPACE get secret $K8S_SA_SECRET_NAME -o yaml | yq '.data.token' -M -I=0)
kubectl -n $NAMESPACE create secret generic ai-rh-developer-hub-env \
    --from-literal=NODE_TLS_REJECT_UNAUTHORIZED=$(echo "0" | base64) \
    --from-literal=K8S_SA_TOKEN=${K8S_SA_TOKEN} \
    --from-literal=GITLAB__APP__CLIENT__ID=$(echo '<gitlab_app_client_id>' | base64) \
    --from-literal=GITLAB__APP__CLIENT__SECRET=$(echo '<gitlab_app_client_secret>' | base64) \
    --from-literal=GITLAB__TOKEN=$(echo '<gitlab_pat>' | base64)
```

**Both**

```sh
K8S_SA_SECRET_NAME=$(kubectl get secrets -n "$NAMESPACE" -o name | grep rhdh-kubernetes-plugin-token- | cut -d/ -f2 | head -1)
K8S_SA_TOKEN=$(kubectl -n $NAMESPACE get secret $K8S_SA_SECRET_NAME -o yaml | yq '.data.token' -M -I=0)
kubectl -n $NAMESPACE create secret generic ai-rh-developer-hub-env \
    --from-literal=NODE_TLS_REJECT_UNAUTHORIZED=$(echo "0" | base64) \
    --from-literal=K8S_SA_TOKEN=${K8S_SA_TOKEN} \
    --from-literal=GITHUB__APP__ID=$(echo '<github_app_id>' | base64) \
    --from-literal=GITHUB__APP__CLIENT__ID=$(echo '<github_app_client_id>' | base64) \
    --from-literal=GITHUB__APP__CLIENT__SECRET=$(echo '<github_app_client_secret>' | base64) \
    --from-literal=GITHUB__APP__WEBHOOK__URL=$(echo '<github_app_webhook_url>' | base64) \
    --from-literal=GITHUB__APP__WEBHOOK__SECRET=$(echo '<github_app_webhook_secret>' | base64) \
    --from-file=GITHUB__APP__PRIVATE_KEY='<path-to-app-pk>' \
    --from-literal=GITOPS__GIT_TOKEN=$(echo '<git_pat>' | base64) \
    --from-literal=GITLAB__APP__CLIENT__ID=$(echo '<gitlab_app_client_id>' | base64) \
    --from-literal=GITLAB__APP__CLIENT__SECRET=$(echo '<gitlab_app_client_secret>' | base64) \
    --from-literal=GITLAB__TOKEN=$(echo '<gitlab_pat>' | base64)
```

Notice that `K8S_SA_TOKEN` does not need encoding as the other literal sets, this is because when the value is fetched from the service account token secret it comes back already encoded.

#### Step 2: Setting the Extra Environment Variables Secret to Developer Hub

You will need to set up your developer hub instance to use the Extra Environment Variables Secret you created. To do this you will need to patch the Secret into the deployment by doing either of the following:

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

#### Step 3: Create the Extra App Config ConfigMap

Follow the same steps under [step 2 for the ai-rhdh-installer](#step-2-create-the-extra-app-config-configmap).

#### Step 4: Setting the Extra App Config to Developer Hub

Similar to [step 3 for the ai-rhdh-installer](#step-3-setting-the-extra-app-config-to-developer-hub), you will need to set up your developer hub instance to use the Extra App Config you created. To do this you will need to patch the app config into the deployment spec:

```sh
kubectl get deploy <rhdh-deployment-name> -n $NAMESPACE -o yaml | \
  yq '.spec.template.spec.volumes += {"name": "developer-hub-app-config", "configMap": {"name": "developer-hub-app-config", "defaultMode": 420, "optional": false}} | 
  .spec.template.spec.containers[0].volumeMounts += {"name": "developer-hub-app-config", "readOnly": true, "mountPath": "/opt/app-root/src/app-config.extra.yaml", "subPath": "app-config.extra.yaml"} |
  .spec.template.spec.containers[0].args += ["--config", "/opt/app-root/src/app-config.extra.yaml"]' | \
  kubectl apply -f -
```

**Note**: If you are bringing your own [RHDH Operator](https://github.com/redhat-developer/rhdh-operator) instance, you can follow [step 3 for the ai-rhdh-installer](#step-3-setting-the-extra-app-config-to-developer-hub) instead.

#### Step 5: Updating ArgoCD Plugins

Follow the same steps under either [step 4.1](#step-41-updating-argocd-plugins-via-web-console) or [step 4.2](#step-42-updating-argocd-plugins-via-cli) for the ai-rhdh-installer.

#### Step 6: Updating Tekton Plugins

Follow the same steps under either [step 5.1](#step-51-updating-tekton-plugins-via-web-console) or [step 5.2](#step-52-updating-tekton-plugins-via-cli) for the ai-rhdh-installer.

#### Step 7: Updating Developer Hub Plugins

Follow the same steps under either [step 6.1](#step-61-updating-developer-hub-plugins-via-web-console) or [step 6.2](#step-62-updating-developer-hub-plugins-via-cli) for the ai-rhdh-installer.

#### Step 8: Updating RHDH Deployment with ArgoCD Resources

Now you will need to make sure that all of the ArgoCD tied resources are setup with the developer hub deployment. Run the following to attach the ArgoCD ConfigMap and Secret:

```sh
kubectl get deploy <rhdh-deployment-name> -n $NAMESPACE -o yaml | \
  yq '.spec.template.spec.volumes += [{"name": "argocd-config", "configMap": {"name": "argocd-config", "defaultMode": 420, "optional": false}}] |
  .spec.template.spec.containers[0].envFrom += [{"secretRef": {"name": "rhdh-argocd-secret"}}] |
  .spec.template.spec.containers[0].volumeMounts += [{"name": "argocd-config", "readOnly": true, "mountPath": "/opt/app-root/src/argocd-config.yaml", "subPath": "argocd-config.yaml"}] |
  .spec.template.spec.containers[0].args += ["--config", "/opt/app-root/src/argocd-config.yaml"]' | \
  kubectl apply -f -
```

**Note**: If you are bringing your own [RHDH Operator](https://github.com/redhat-developer/rhdh-operator) instance, you can follow [step 7.2 for the ai-rhdh-installer](#step-72-argocd-config-and-secret) instead.