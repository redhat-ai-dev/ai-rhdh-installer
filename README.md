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

## GitOps/ArgoCD Configuration

Detailed documentation for configuring GitOps/ArgoCD can be found in [`GITOPS-CONFIG.md`](./docs/GITOPS-CONFIG.md)

## Pipelines/Tekton Configuration

Detailed documentation for configuring Pipelines/Tekton can be found in [`PIPELINES-CONFIG.md`](./docs/PIPELINES-CONFIG.md)

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
3. Run `source private.env` to set all set environment variables within `private.env`
