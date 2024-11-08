## GitOps/ArgoCD Configuration

As part of this section you will find information about the following configuration methods:

1. [Configuring GitOps/ArgoCD with the configuration script after using our `ai-rhdh-installer`](#ai-rhdh-installer-script-configuration)
2. [Configuring GitOps/ArgoCD manually after using our `ai-rhdh-installer`](#ai-rhdh-installer-manual-configuration)
3. [**WIP:** Configuring GitOps/ArgoCD with the configuration script for a pre-existing ArgoCD and Red Hat Developer Hub instance](#pre-existing-instance-script-configuration)
4. [**WIP:** Configuring GitOps/ArgoCD manually for a pre-existing ArgoCD and Red Hat Developer Hub instance](#pre-existing-instance-manual-configuration)

### Prerequisites

- [yq](https://github.com/mikefarah/yq/) version 4.0+
- [kubectl](https://github.com/kubernetes/kubectl) or [oc](https://docs.openshift.com/container-platform/4.16/cli_reference/openshift_cli/getting-started-cli.html) version compatible with your target cluster

### AI-RHDH-Installer: Script Configuration
If you installed using the [`ai-rhdh-installer`](../README.md#install) all that is required for hooking up the ArgoCD instance to your RHDH instance is to run `bash ./scripts/configure-gitops.sh`. Please note if you changed the installation namespace used by the installer you will first need to run `export NAMESPACE=<namespace used>` as the default value is `ai-rhdh`.

### AI-RHDH-Installer: Manual Configuration
In your chosen namespace you should apply the `argocd-config` ConfigMap under [`argocd-config.yaml` ](../resources/argocd-config.yaml).

As part of the `ai-rhdh-installer` a secret was created in your desired namespace with the name `rhdh-argocd-secret`, keep note of this Secret as well as the two ConfigMaps applied above.

### WIP: Pre-Existing Instance: Script Configuration
If you have your own ArgoCD instance created you can configure it to work with RHDH with the use of our config script. You will need the following information on hand:

1. Namespace of RHDH & ArgoCD instance
2. Deployment name of RHDH
3. ConfigMap name for your RHDH plugins
   1. Typically `dynamic-plugins` for `Helm` installs and `backstage-dynamic-plugins-<name of developer hub instance>` for `Operator` installs
4. ArgoCD user with token permissions
5. Password for ArgoCD user
6. ArgoCD hostname
   1. Typically `.spec.host` of the `route` for ArgoCD
7. Token associated with the ArgoCD user

You are able to store these values in environment variables or paste them during the interactive prompts at runtime. Set the following the use environment variables:
- `$EXISTING_NAMESPACE`
- `$EXISTING_DEPLOYMENT`
- `$RHDH_PLUGINS`
- `$ARGO_USERNAME`
- `$ARGO_PASSWORD`
- `$ARGO_HOSTNAME`
- `$ARGO_TOKEN`
- `$ARGO_INSTANCE_NAME`

Once you have that information readily available you can follow:

1. Run `export ARGOCD_INSTANCE_PROVIDED=true`
2. Run `bash ./scripts/configure-gitops.sh` and follow the prompts in the command line

### WIP: Pre-Existing Instance: Manual Configuration

#### Step 1: Required Information
You will need the following information on hand to properly configure an existing ArgoCD instance with RHDH:

- ArgoCD User (with permissions for creating tokens)
- Password for the user
- ArgoCD hostname
  - Typically found under `.spec.host` for your ArgoCD `route`
- Token

#### Step 2: ConfigMaps and Secrets
In your chosen namespace you should apply the `argocd-config` ConfigMap under [`argocd-config.yaml` ](../resources/argocd-config.yaml).

You will also need to create a Secret in your chosen namespace with the following key:value pairs and information gathered in [step 1](#step-1-required-information):
1. `ARGOCD_USER`
2. `ARGOCD_PASSWORD`
3. `ARGOCD_HOSTNAME`
4. `ARGOCD_API_TOKEN`
