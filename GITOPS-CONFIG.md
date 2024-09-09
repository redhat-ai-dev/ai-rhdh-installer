## GitOps/ArgoCD Configuration

As part of this section you will find information about the following configuration methods:

1. Configuring GitOps/ArgoCD with the configuration script after using our `ai-rhdh-installer`
2. Configuring GitOps/ArgoCD manually after using our `ai-rhdh-installer`
3. Configuring GitOps/ArgoCD with the configuration script for a pre-existing ArgoCD and Red Hat Developer Hub instance
4. Configuring GitOps/ArgoCD manually for a pre-existing ArgoCD and Red Hat Developer Hub instance

### Prerequisites
<!---
TODO: Once RHDH configuration is complete we should link a reference to it here.
-->
- In order to allow the configuration to be completed you must first have a working Red Hat Developer Hub (RHDH) instance (for example you are able to login and view Developer Hub).
- [yq](https://github.com/mikefarah/yq/) version 4.0+.

### AI-RHDH-Installer: Script Configuration
If you installed using the `ai-rhdh-installer` all that is required for hooking up the ArgoCD instance to your RHDH instance is to run `bash ./scripts/configure-gitops.sh`. Please note if you changed the installation namespace used by the installer you will first need to run `export NAMESPACE=<namespace used>` as the default value is `ai-rhdh`.

### AI-RHDH-Installer: Manual Configuration

#### Step 1: ConfigMaps and Secrets
In your chosen namespace you should apply the following ConfigMaps:
1.  [`argocd-config.yaml` ](./resources/argocd-config.yaml)
2.  [`argocd-plugins.yaml`](./resources/argocd-plugins.yaml)

As part of the `ai-rhdh-installer` a secret was created in your desired namespace with the name `rhdh-argocd-secret`, keep note of this Secret as well as the two ConfigMaps applied above.

#### Step 2: Updating Plugins
**Note: RHDH will encounter errors if the ArgoCD plugins are loaded before an instance is properly attached - This step may result in errors until all steps are completed**

To include the ArgoCD plugins we need to edit the dynamic plugins ConfigMap that was created by the RHDH Operator:

![Dynamic Plugins Example](./assets/dynamic-plugins-example.png)

Edit the associated `yaml` file to include `argocd-plugins.yaml` under the `includes` section:

![Dynamic Plugins Example 2](./assets/dynamic-plugins-example-2.png)

#### Step 3: Updating RHDH Deployment
Now that all of the required ConfigMaps and Secrets are apart of the namespace, as well as adding the plugins we must edit the RHDH Deployment to properly reference these items.

Since we are referencing `argocd-plugins.yaml` in our dynamic-plugins ConfigMap we first must add `argocd-plugins.yaml` as a `volumeMount` to the `initContainers` field in the RHDH Deployment under `.spec.template.spec.initContainers.volumeMounts`

![ArgoCD Plugins Addition](./assets/argocd-plugins-example.png)

Next we will need to add the `argocd-config.yaml` as a `VolumeMount` to the `containers` field in the RHDH Deployment under `.spec.template.spec.containers.volumeMounts`

![ArgoCD Config Addition](./assets/argocd-config-example.png)

Next add the created `rhdh-argocd-secret` to the `envFrom` field in the RHDH Deployment under `.spec.template.spec.containers.envFrom`

![ArgoCD Secret Addition](./assets/argocd-secrets-example.png)

Now we must update the config args used by RHDH to include our ArgoCD ConfigMap. This is added to the `args` field in the RHDH Deployment under `.spec.template.spec.containers.args`

![ArgoCD Config Update](./assets/argocd-config-addition.png)

Finally we need to add the resources included as `volumeMounts` to the `volumes` field in the RHDH Deployment under `.spec.template.spec.volumes`

![ArgoCD Volumes Addition](./assets/argocd-volumes-example.png)

### Pre-Existing Instance: Script Configuration
If you have your own ArgoCD instance created you can configure it to work with RHDH with the use of our config script. You will need the following information on hand:

1. Namespace of RHDH & ArgoCD instance
2. Deployment name of RHDH
3. ConfigMap name for your RHDH plugins
   1. Typically `dynamic-plugins` for `Helm` installs and `backstage-dynamic-plugins-<name of developer hub instance>` for `Operator` installs
4. ArgoCD user with token permissions
5. Password for ArgoCD user
6. ArgoCD hostname
   1. Typically `.spec.host` of the `route` for ArgoCD
7. Token associatd with the ArgoCD user

Once you have that information readily available you can follow:

1. Run `export ARGOCD_INSTANCE_PROVIDED=true`
2. Run `bash ./scripts/configure-gitops.sh` and follow the prompts in the command line

### Pre-Existing Instance: Manual Configuration

#### Step 1: Required Information
You will need the following information on hand to properly configure an existing ArgoCD instance with RHDH:

- ArgoCD User (with permissions for creating tokens)
- Password for the user
- ArgoCD hostname
  - Typically found under `.spec.host` for your ArgoCD `route`
- Token

#### Step 2: ConfigMaps and Secrets
In your chosen namespace you should apply the following ConfigMaps:
1.  [`argocd-config.yaml` ](./resources/argocd-config.yaml)
2.  [`argocd-plugins.yaml`](./resources/argocd-plugins.yaml)

You will also need to create a Secret in your chosen namespace with the following key:value pairs and information gathered in [step 1](#step-1-required-information):
1. `ARGOCD_USER`
2. `ARGOCD_PASSWORD`
3. `ARGOCD_HOSTNAME`
4. `ARGOCD_API_TOKEN`

#### Step 3: Updating Plugins
You will follow the same steps as [step 2 for the ai-rhdh-installer](#ai-rhdh-installer-script-configuration)

#### Step 4: Updating RHDH Deployment
Once you have applied the ConfigMaps and Secrets to your cluster and the necessary namespace you can now follow the same steps in [step 3 for the ai-rhdh-installer](#ai-rhdh-installer-manual-configuration). Every step will be identical if your RHDH instance was created using the `Red Hat Developer Hub Operator`, however, if you installed RHDH using the `Helm Chart` you may find that `.spec.template.spec.containers.envFrom` does not exist in the Deployment yaml. If this is the case you can simply add that field and the necessary secret information.

Additionally, if RHDH was installed with `Helm` the naming for the RHDH Deployment and ConfigMap (for the dynamic plugins) may differ than the example but the content will look similar so you can reference that to find the proper files.