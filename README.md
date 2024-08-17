# Red Hat Developer Hub Installer

This helm chart installs and configures the following operators:

|       Product       |      Installation       |                                                                                                      Configuration                                                                                                       |
| :-----------------: | :---------------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
|  OpenShift GitOps   | Operator `Subscription` |                                    Controlled by the values YAML file. If a subscription already exists, the installation will not modify it. A new instance ArgoCD will be created.                                     |
| OpenShift Pipelines | Operator `Subscription` | Controlled by the values YAML file. If a subscription already exists, the installation will not modify it. In all cases, the TektonConfig will be modified to enable Tekton Chains and the signing secret will be setup. |

**Note**: If a subscription for an operator already exists, the installation will not tamper with it.

## Requirements

- Helm CLI (more information [here](https://helm.sh/docs/intro/install/))

## CLI

### Install

Run `helm upgrade --install <release-name> <path-to-chart>` to deploy default installations of the necessary operators.

#### Example

`helm upgrade --install setup-default-operators ./chart`

### Uninstall

Since for the default installation the `ServiceAccount` is being deployed to the `default` namespace with admin permissions you are unable to remove it during a `helm uninstall`. You first need to remove the ServiceAccount manually before running `helm uninstall`

Reference: https://access.redhat.com/solutions/7055600

`oc delete sa helm-manager --as backplane-cluster-admin`

After the ServiceAccount is removed, run `helm uninstall <release-name>`
