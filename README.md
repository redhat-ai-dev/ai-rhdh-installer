# Red Hat Developer Hub Installer for AI Software Templates

This helm chart installs and configures the following operators:

|       Product       |      Installation       |                                                                                                      Configuration                                                                                                       |
| :-----------------: | :---------------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
|  OpenShift GitOps   | Operator `Subscription` |                                    Controlled by the values YAML file. If a subscription already exists, the installation will not modify it. A new instance of ArgoCD will be created.                                     |
| OpenShift Pipelines | Operator `Subscription` | Controlled by the values YAML file. If a subscription already exists, the installation will not modify it. In all cases, the TektonConfig will be modified to enable Tekton Chains and the signing secret will be setup. |
| Red Hat Developer Hub | Operator `Subscription` | Controlled by the values YAML file. If a subscription already exists, the installation will not modify it. A new instance of RHDH will be created. |

**Note**: If a subscription for an operator already exists, the installation will not tamper with it.

## Requirements

- Helm CLI (more information [here](https://helm.sh/docs/intro/install/))
- A GitHub App and its associated information (c.f. [Create a Pipelines-as-Code GitHub App](https://pipelinesascode.com/docs/install/github_apps/)).
  - `General`
    - Use placeholder values for `Homepage URL`, `Callback URL` and `Webhook URL`.
    - Generate a `Webhook secret`.
  - `Permissions & events`
    - Follow the instructions from the Pipelines-as-Code documentation.
    - `Repository permissions`
      - `Administration`: `Read and write`
- The GitHub App must be installed at the organization/user level.

## CLI

### Install

Run `helm upgrade --install <release-name> <path-to-chart> --namespace <namespace> --create-namespace` to deploy default installations of the necessary operators.

#### Example

`helm upgrade --install ai-rhdh ./chart --namespace ai-rhdh --create-namespace`

### Uninstall

`helm uninstall <release-name> --namespace <namespace>`

### Default Namespace

This installer is incompatible with `default` namespace installations, install and uninstall commands must include `--namespace <target-namespace>` or the context namespace must be changed, e.g. `oc project <target-namespace>`.

## Configuration

For convenience you can configure your Red Hat Developer Hub, GitOps, and Pipelines Operators to enable the use of AI Software Templates by running the following:

`bash ./configure.sh`

**Note**: If you changed the installation namespace used by the installer you will first need to run `export NAMESPACE=<namespace used>` as the default value is `ai-rhdh`.

Alternatively, if you do not wish to use the all-in-one `configure.sh` script, you can find documentation below for configuring each component individually.

### GitOps/ArgoCD Configuration

Detailed documentation for configuring GitOps/ArgoCD can be found in [`GITOPS-CONFIG.md`](./docs/GITOPS-CONFIG.md)

### Pipelines/Tekton Configuration

Detailed documentation for configuring Pipelines/Tekton can be found in [`PIPELINES-CONFIG.md`](./docs/PIPELINES-CONFIG.md)

### Developer Hub Configuration

**Note**: It is required to go through the steps under documentation mentioned in [GitOps/ArgoCD Configuration](#gitopsargocd-configuration) and [Pipelines/Tekton Configuration](#pipelinestekton-configuration) before the steps under the documentation below.

Detailed documentation for configuring Developer Hub can be found in [`RHDH-CONFIG.md`](./docs/RHDH-CONFIG.md)

### Lightspeed Plugin Configuration

The Lightspeed plugin is installed as part of the Developer Hub configuration script if the `LIGHTSPEED_MODEL_URL` environment variable is set. Optionally, set the variable `LIGHTSPEED_API_TOKEN` for authenticated communication with the model service.

## Setting Environment Variables for Configuration Scripts

Configuration scripts can either take user input or can have environment variables set to skip manual input. To do this, follow the steps below:

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
    - `LIGHTSPEED_MODEL_URL`
        - Target model URL for lightspeed plugin
    - `LIGHTSPEED_API_TOKEN`
        - API token for lightspeed plugin model service
3. Run `source private.env` to set all set environment variables within `private.env`

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
