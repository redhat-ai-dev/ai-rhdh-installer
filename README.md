# Red Hat Developer Hub Installer for AI Software Templates
 
> [!IMPORTANT] 
> This repository contains both a Helm chart for installing OpenShift Operators, as well as configuration scripts for configuring those Operators to enable AI Software Templates in Red Hat Developer Hub.

## Requirements

- OpenShift (more information [here](https://www.redhat.com/en/technologies/cloud-computing/openshift) or [create](https://console.redhat.com/openshift/create) your OpenShift cluster). Tested on OpenShift 4.15. More information [here](https://access.redhat.com/support/policy/updates/developerhub) for supported OpenShift versions with Red Hat Developer Hub version 1.2.
- OpenShift AI (optional, more information [here](https://www.redhat.com/en/technologies/cloud-computing/openshift/openshift-ai)).
- Helm CLI (more information [here](https://helm.sh/docs/intro/install/)).
- GitHub or GitLab app created via [APP-SETUP.md](./docs/APP-SETUP.md).
- [Quay](https://quay.io/) image registry (more information [here](./docs/APP-SETUP.md#quay-setup)).
- [yq](https://github.com/mikefarah/yq/) version 4.0+
- [kubectl](https://github.com/kubernetes/kubectl) or [oc](https://docs.openshift.com/container-platform/4.16/cli_reference/openshift_cli/getting-started-cli.html) version compatible with your target cluster

## Helm Chart Installer

> [!IMPORTANT]
> It is recommended you run the Helm chart on a fresh cluster that does not have pre-existing GitOps/ArgoCD, Pipelines/Tekton and Developer Hub Operators.

This Helm chart installs and configures the following operators:

|       Product       |      Installation       |                                                                                                      Configuration                                                                                                       |
| :-----------------: | :---------------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
|  OpenShift GitOps   | Operator `Subscription` |                                    Controlled by the values YAML file. If a subscription already exists, the installation will not modify it. A new instance of ArgoCD will be created.                                     |
| OpenShift Pipelines | Operator `Subscription` | Controlled by the values YAML file. If a subscription already exists, the installation will not modify it. In all cases, the TektonConfig will be modified to enable Tekton Chains and the signing secret will be setup. |
| Red Hat Developer Hub | Operator `Subscription` | Controlled by the values YAML file. If a subscription already exists, the installation will not modify it. A new instance of RHDH will be created. |

**Note**: If a subscription for an operator already exists, the installation will not tamper with it.

### Install

>[!WARNING]
> This installer is incompatible with the `default` namespace. Install and uninstall commands *must* include `--namespace <target-namespace>`, or the context namespace should e updated. E.g. `oc project <target-namespace>`.

To deploy default installations of the above Operators, run:
```
helm upgrade --install <release-name> <path-to-chart> --namespace <namespace> --create-namespace
```

For example, to deploy this Helm chart to the `ai-rhdh` namespace you can run:
```
helm upgrade --install ai-rhdh ./chart --namespace ai-rhdh --create-namespace
```

### Uninstall

To uninstall the Operators, run:
```
helm uninstall <release-name> --namespace <namespace>
```

### Helm Troubleshooting

If you find the `ArgoCD Operator` is installed but the configuration is failing due to `context exceeded`, please ensure that `skip-test-tls` is set to `true` in your [values.yaml](./chart/values.yaml) file.

You can pass the `skip-test-tls` value as a flag in your Helm upgrade command as well if you prefer:
```
helm upgrade --install ai-rhdh ./chart --namespace ai-rhdh --create-namespace --set openshift-gitops.skip-test-tls=true
```

## Configuration

> [!IMPORTANT] 
> It is recommended you configure using the `configure.sh` script listed below. Configuration options for pre-existing instances are a work-in-progress (WIP), you can find this information here:
>- [Pre-existing GitOps/ArgoCD Instances](./docs/GITOPS-CONFIG.md)
>- [Pre-existing Pipelines/Tekton Instances](./docs/PIPELINES-CONFIG.md)
>- [Pre-existing Developer Hub Instances](./docs/RHDH-CONFIG.md)

For convenience you can configure your Red Hat Developer Hub, GitOps, and Pipelines Operators to enable the use of AI Software Templates by running the following from the root of this repository:
```
bash ./configure.sh
```
**Note**: If you changed the installation namespace used by the installer you will first need to run `export NAMESPACE=<namespace used>` as the default value is `ai-rhdh`.

For information related to extra configuration options, see [`docs/EXTRA-CONFIG.md`](./docs/EXTRA-CONFIG.md).
