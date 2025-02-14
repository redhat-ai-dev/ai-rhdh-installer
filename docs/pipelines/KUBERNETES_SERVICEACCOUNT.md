# Setting Up Kubernetes Service Accounts

## Creating The Service Account

You will need to create a Service Account that RHDH needs to interact with the cluster. The yaml snippet found below can be used to easily create a Service Account.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rhdh-kubernetes-plugin
  namespace: <desired-namespace>
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: rhdh-kubernetes-plugin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
  - kind: ServiceAccount
    name: rhdh-kubernetes-plugin
    namespace: <desired-namespace>
```

## Creating The Service Account Token

In Kubernetes v1.24 and above the token associated with a Service Account is not auto-generated, due to this we will manually create the Service Account Token Secret. This is compatible even for Kubernetes versions older than v1.24.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: rhdh-kubernetes-plugin-token
  namespace: <desired-namespace>
  annotations:
    kubernetes.io/service-account.name: rhdh-kubernetes-plugin
type: kubernetes.io/service-account-token
```