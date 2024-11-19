## Installer Provisioned GitOps/ArgoCD Configuration

This document covers the configuration of an OpenShift GitOps/ArgoCD Operator after the Operator was installed using our [`ai-rhdh-installer`](../../README.md#helm-chart-installer) Helm chart.

### Prerequisites

- [yq](https://github.com/mikefarah/yq/) version 4.0+
- [kubectl](https://github.com/kubernetes/kubectl) or [oc](https://docs.openshift.com/container-platform/4.16/cli_reference/openshift_cli/getting-started-cli.html) version compatible with your target cluster

### Script Configuration

Run `bash ./scripts/configure-gitops.sh` from the root of this repository to start the configuration process using our configuration scripts. Please note if you changed the installation namespace used by the installer you first need to run `export NAMESPACE=<namespace-used>` as the default value is `ai-rhdh`.

### Manual Configuration

You are able to avoid using our configuration script and opt to manually add all of the configuration by following the steps below.

1. In your chosen namespace, apply the `argocd-config` ConfigMap located under [`/resources/argocd-config.yaml`](../../resources/argocd-config.yaml).
2. The Helm chart install created the appropriate Secret, `rhdh-argocd-secret` in your chosen namespace that the ConfigMap will reference.