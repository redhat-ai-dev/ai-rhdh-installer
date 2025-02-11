## Pre-Existing Pipelines/Tekton Configuration

> [!IMPORTANT] 
> Currently support for pre-existing Pipelines/Tekton instances is a work-in-progress (WIP)

### Script Configuration

#### Step 1: Required Information

If you have your own RHDH instance created you can configure it to work with the pipelines service with the use of our config script. You will need the following information on hand:

1. Namespace of RHDH instance
2. Deployment name of RHDH
3. ConfigMap name for your RHDH plugins
   1. Typically `dynamic-plugins` for `Helm` installs and `backstage-dynamic-plugins-<name of developer hub instance>` for `Operator` installs
4. Kubernetes API service account

#### Step 2: Environment Variables

You are able to store these values in environment variables. Set the following the use environment variables:
- `$EXISTING_NAMESPACE`
  - Name of target RHDH namespace
- `$EXISTING_DEPLOYMENT`
  - Name of target RHDH deployment
- `$RHDH_PLUGINS`
  - Name of the dynamic plugins ConfigMap

#### Step 3: Configure cosign

The installer will configure and set up cosign that the `configure-pipeline.sh` script needs to reference the cosign public key to set to the cosign secret under the deployment namespaces.

To configure cosign to sign secrets follow these steps:
1. Download `cosign` cli tool
    1. Set the architecture you are on `ARCH=<architecture>`, for example `amd64` or `arm64`
    2. Set the kind of operating system you are using `OS=<operating-system>`, for example `linux` or `darwin`
    3. Download using `curl`
        ```sh
        curl -L https://github.com/sigstore/cosign/releases/latest/download/cosign-$OS-$ARCH -o cosign && chmod +x cosign
        ```
2. Delete the default secret if it exists
    ```sh
    kubectl delete secrets -n "openshift-pipelines" "signing-secrets" --ignore-not-found=true
    ```
3. Create a random password
    ```sh
    RANDOM_PASS=$( openssl rand -base64 30 )
    ```
4. Generate the key pair secret directly in the cluster, the secret should be created as immutable
    ```sh
    env COSIGN_PASSWORD=$RANDOM_PASS ./cosign generate-key-pair "k8s://openshift-pipelines/signing-secrets" >/dev/null
    ```
5. If the secret is not marked as immutable, make it so
    ```sh
    kubectl patch secret -n "openshift-pipelines" "signing-secrets" \
        --dry-run=client -o yaml \
        --patch='{"immutable": true}' \
        | kubectl apply -f - >/dev/null
    ````


#### Step 4: Run Configure Script

Once you have done the prior steps and have the information from the prior steps readily available you can follow:

1. Run `export RHDH_INSTANCE_PROVIDED=true`
2. Run `bash ./scripts/configure-pipelines.sh` and follow the prompts in the command line

### Manual Configuration
<!-- TODO: Update these links since they are in separate files now -->
#### Step 1: Configure cosign

You will follow the same steps as [step 3 of the script configuration for a pre-existing instance](#step-3-configure-cosign).

#### Step 2: Kubernetes API Service Account
First you will need to create the [service account](../../chart/templates/k8s-serviceaccount.yaml)
that RHDH will need to interact with the cluster such as
creating tekton pipeline runs.

Once the service account is created there will be a tied secret which stores the service account token, e.g. if a service account `rhdh-kubernetes-plugin` is created then a secret with the name `rhdh-kubernetes-plugin-token` is also created.

Keep note of the name of this secret.

#### Step 3: Create App Namespace Setup Task

You will follow the same steps as [step 3 for the ai-rhdh-installer provisioned operators](./INSTALLER-PROVISIONED.md#step-3-create-app-namespace-setup-task)

#### Step 4: Setting up deployment namespaces \(Optional\)

You can follow the following same steps for setting up the deployment namespaces with the ai-rhdh-installer:

1. [Setting up deployment namespaces](./INSTALLER-PROVISIONED.md#step-4-setting-up-deployment-namespaces-optional)
2. [Setting up cosign secret under deployment namespaces](./INSTALLER-PROVISIONED.md#step-5-setting-up-cosign-secret-under-deployment-namespaces-optional)
3. [Setting up gitops authentication secret under deployment namespaces](./INSTALLER-PROVISIONED.md#step-6-setting-up-gitops-authentication-secret-under-deployment-namespaces-optional)
4. [Setting up pipelines secret under deployment namespaces](./INSTALLER-PROVISIONED.md#step-7-setting-up-pipelines-secret-under-deployment-namespaces-optional)
5. [Setting up quay image registry secret under deployment namespaces](./INSTALLER-PROVISIONED.md#step-8-setting-up-quay-image-registry-secret-under-deployment-namespaces-optional)
