# Red Hat Developer Hub Installer for AI Software Templates

> [!IMPORTANT] 
> Currently, only the **GitHub Authentication** is supported. **GitLab Authentication** is planned for future versions.

This helm chart installs and configures the following operators:

|       Product       |      Installation       |                                                                                                      Configuration                                                                                                       |
| :-----------------: | :---------------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
|  OpenShift GitOps   | Operator `Subscription` |                                    Controlled by the values YAML file. If a subscription already exists, the installation will not modify it. A new instance of ArgoCD will be created.                                     |
| OpenShift Pipelines | Operator `Subscription` | Controlled by the values YAML file. If a subscription already exists, the installation will not modify it. In all cases, the TektonConfig will be modified to enable Tekton Chains and the signing secret will be setup. |
| Red Hat Developer Hub | Operator `Subscription` | Controlled by the values YAML file. If a subscription already exists, the installation will not modify it. A new instance of RHDH will be created. |

**Note**: If a subscription for an operator already exists, the installation will not tamper with it.

## Requirements

- OpenShift (more information [here](https://www.redhat.com/en/technologies/cloud-computing/openshift) or [create](https://console.redhat.com/openshift/create) your OpenShift cluster). Tested on OpenShift 4.15. More information [here](https://access.redhat.com/support/policy/updates/developerhub) for supported OpenShift versions with Red Hat Developer Hub version 1.2.
- OpenShift AI (optional, more information [here](https://www.redhat.com/en/technologies/cloud-computing/openshift/openshift-ai)).
- Helm CLI (more information [here](https://helm.sh/docs/intro/install/)).
- GitHub or GitLab app created via [APP-SETUP.md](./docs/APP-SETUP.md).
- [Quay](https://quay.io/) image registry (more information [here](./docs/APP-SETUP.md#quay-setup)).

## Helm Chart Installer

> [!IMPORTANT]
> It is recommended you run the Helm chart on a fresh cluster that does not have pre-existing GitOps/ArgoCD, Pipelines/Tekton and Developer Hub Operators.

### Install

Run `helm upgrade --install <release-name> <path-to-chart> --namespace <namespace> --create-namespace` to deploy default installations of the necessary operators.

#### Example

`helm upgrade --install ai-rhdh ./chart --namespace ai-rhdh --create-namespace`

### Uninstall

`helm uninstall <release-name> --namespace <namespace>`

### Default Namespace

This installer is incompatible with `default` namespace installations, install and uninstall commands must include `--namespace <target-namespace>` or the context namespace must be changed, e.g. `oc project <target-namespace>`.

## Configuration

> [!IMPORTANT] 
> It is recommended you configure using the `configure.sh` script listed below. Configuration options for pre-existing instances are a work-in-progress (WIP), you can find this information here:
>- [Pre-existing GitOps/ArgoCD Instances](./docs/GITOPS-CONFIG.md)
>- [Pre-existing Pipelines/Tekton Instances](./docs/PIPELINES-CONFIG.md)
>- [Pre-existing Developer Hub Instances](./docs/RHDH-CONFIG.md)

For convenience you can configure your Red Hat Developer Hub, GitOps, and Pipelines Operators to enable the use of AI Software Templates by running the following from the root of this repository:

`bash ./configure.sh`

**Note**: If you changed the installation namespace used by the installer you will first need to run `export NAMESPACE=<namespace used>` as the default value is `ai-rhdh`.

See the following for further customization of the configuration:

- [Enabling GitLab Integration](#gitlab-integration)
- [Setting Environment Variables](#setting-environment-variables-for-configuration-scripts)
- [Setting Catalogs for Developer Hub Configuration](#setting-catalogs-for-developer-hub-configuration)

## GitLab Integration

To configure RHDH to use GitLab as the git repository source, you will need to first run `export RHDH_GITLAB_INTEGRATION=true` before running any of the [configuration](#configuration) scripts. Run `export RHDH_GITHUB_INTEGRATION=false` to disable GitHub integration.

### Lightspeed Plugin Configuration

The Lightspeed plugin is installed as part of the Developer Hub configuration script if the `LIGHTSPEED_INTEGRATION` environment variable is set to `true`. This will require setting the variable `LIGHTSPEED_MODEL_URL` to the desired model endpoint. Optionally, set the variable `LIGHTSPEED_API_TOKEN` for authenticated communication with the model service.

## Setting Environment Variables for Configuration Scripts

For more information regarding where you can obtain these values see [APP-SETUP.md](./docs/APP-SETUP.md)

Configuration scripts can either take user input or can have environment variables set to skip manual input. If you opt to do the manual input, a `private.env` file will be created for you at the end for future use. To preset your `private.env` and avoid manual input via CLI, follow the steps below:

1. Run `cp default-private.env private.env` to copy the starting point into a private environment variables file
2. Set each of these environment variables to the private values needed for the configuration scripts, surround all multiline values with `''`
    - `GITHUB__APP__ID`
        - GitHub Organization App ID
    - `GITHUB__APP__CLIENT__ID`
        - GitHub Org App Client ID (alternative to `GITLAB__APP__CLIENT__ID`)
    - `GITHUB__APP__CLIENT__SECRET`
        - GitHub Org App Client Secret (alternative to `GITLAB__APP__CLIENT__SECRET`)
    - `GITHUB__APP__WEBHOOK__URL`
        - GitHub App Webhook URL to pipelines as code service
    - `GITHUB__APP__WEBHOOK__SECRET`
        - User set GitHub App Webhook Secret
    - `GITHUB__APP__PRIVATE_KEY`
        - GitHub App Private Key
    - `GITOPS__GIT_TOKEN`
        - Git Personal Access Token (alternative to `GITLAB__TOKEN`)
    - `GITLAB__APP__CLIENT__ID`
        - GitLab App Client ID (alternative to `GITHUB__APP__CLIENT__ID`)
    - `GITLAB__APP__CLIENT__SECRET`
        - GitLab App Client Secret (alternative to `GITHUB__APP__CLIENT__SECRET`)
    - `GITLAB__TOKEN`
        - GitLab Personal Access Token (alternative to `GITOP__GIT_TOKEN`)
    - `QUAY__DOCKERCONFIGJSON`
        - Docker Config JSON File with Authentication Credentials for a given [Quay.io](https://quay.io) Account
    - `QUAY__API_TOKEN`
        - Quay Org API Token
    - `RHDH_GITHUB_INTEGRATION`
        - Toggle GitHub integration (login). Accepts `true` or `false`
    - `RHDH_GITLAB_INTEGRATION`
        - Toggle GitLab integration (login). Accepts `true` or `false`
    - `LIGHTSPEED_INTEGRATION`
        - Toggle installing the lightspeed plugin
    - `LIGHTSPEED_MODEL_URL`
        - Target model URL for lightspeed plugin
    - `LIGHTSPEED_API_TOKEN`
        - API token for lightspeed plugin model service

## Setting Catalogs for Developer Hub Configuration

The [`configure-dh.sh`](./scripts/configure-dh.sh) script uses [`catalogs.yaml`](catalogs.yaml) by default, you can provide your own custom catalogs URL list instead by following these steps:
1. Create a yaml file to use as your catalogs URL list, content should begin with `catalogs` at root level as follows:
```yaml
catalogs:
```
2. Add the link(s) to the catalog files you wish to include in your developer hub deployment:
```yaml
catalogs:
    - https://github.com/<org-or-user>/ai-lab-template/blob/main/all.yaml
```
3. Export `CATALOGS_FILE` to be set to your file:
```sh
export CATALOGS_FILE=<path-to-your-catalogs-list-file>
```
4. Now when you run `configure-dh.sh` it should use `<path-to-your-catalogs-list-file>` instead
