# AI RHDH Installer

## Installation

Run `helm upgrade --install <release-name> <path-to-chart>` to deploy default installations of the necessary operators.

#### Example Install

`helm upgrade --install setup-default-operators ./chart`

## Troubleshooting

Since for the default installation the ServiceAccount is being deployed to the `default` namespace with admin permissions you are unable to remove it during a `helm uninstall`. You first need to remove the ServiceAccount manually before running `helm uninstall`

Reference: https://access.redhat.com/solutions/7055600

`oc delete sa helm-manager --as backplane-cluster-admin`
