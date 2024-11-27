## Pre-Existing GitOps/ArgoCD Configuration

> [!IMPORTANT] 
> Currently support for pre-existing GitOps/ArgoCD instances is a work-in-progress (WIP)

This document covers the configuration of a pre-existing OpenShift GitOps/ArgoCD Operator. This means the Operator was already present in the cluster, and in some cases, may be in use by other consumers.

### Script Configuration

If you have your own GitOps/ArgoCD instance created, you can configure it to work with RHDH with the use of our config script. You will need the following information on hand:

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
- `EXISTING_NAMESPACE`
- `EXISTING_DEPLOYMENT`
- `RHDH_PLUGINS`
- `ARGO_USERNAME`
- `ARGO_PASSWORD`
- `ARGO_HOSTNAME`
- `ARGO_TOKEN`
- `ARGO_INSTANCE_NAME`

Once you have that information readily available you can follow:

1. Run `export ARGOCD_INSTANCE_PROVIDED=true`
2. Run `bash ./scripts/configure-gitops.sh` and follow the prompts in the command line

### Manual Configuration

#### Step 1: Required Information
You will need the following information on hand to properly configure an existing ArgoCD instance with RHDH:

- ArgoCD User (with permissions for creating tokens)
- Password for the user
- ArgoCD hostname
  - Typically found under `.spec.host` for your ArgoCD `route`
- Token

#### Step 2: ConfigMaps and Secrets
In your chosen namespace you should apply the `argocd-config` ConfigMap under [`argocd-config.yaml` ](../../resources/argocd-config.yaml).

You will also need to create a Secret in your chosen namespace with the following key:value pairs and information gathered in [step 1](#step-1-required-information):
1. `ARGOCD_USER`
2. `ARGOCD_PASSWORD`
3. `ARGOCD_HOSTNAME`
4. `ARGOCD_API_TOKEN`