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

Detailed documentation for configuring GitOps/ArgoCD can be found in [`GITOPS-CONFIG.md`](./GITOPS-CONFIG.md)