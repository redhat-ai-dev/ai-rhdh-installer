# Red Hat Developer Hub Installer for AI Software Templates

This helm chart installs and configures the following operators:

|       Product       |      Installation       |                                                                                                      Configuration                                                                                                       |
| :-----------------: | :---------------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
|  OpenShift GitOps   | Operator `Subscription` |                                    Controlled by the values YAML file. If a subscription already exists, the installation will not modify it. A new instance ArgoCD will be created.                                     |
| OpenShift Pipelines | Operator `Subscription` | Controlled by the values YAML file. If a subscription already exists, the installation will not modify it. In all cases, the TektonConfig will be modified to enable Tekton Chains and the signing secret will be setup. |

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

`helm upgrade --install ai-rhdh ./chart --namespace rhdh --create-namespace`

### Uninstall

`helm uninstall <release-name> --namespace <namespace>`

#### Default Namespace

Since for the default installation the ServiceAccount is being deployed to the `default` namespace with admin permissions you are unable to remove it during a `helm uninstall`. You first need to remove the ServiceAccount manually before running `helm uninstall`

Reference: https://access.redhat.com/solutions/7055600

`oc delete sa helm-manager --as backplane-cluster-admin`

After the ServiceAccount is removed, run `helm uninstall <release-name>`
