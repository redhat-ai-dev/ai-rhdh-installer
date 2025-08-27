# Remote Cluster Configuration

This document describes how to configure multiple Kubernetes clusters in your Red Hat Developer Hub (RHDH) installation to enable multi-cluster visibility for Kubernetes resources, Tekton pipelines, and ArgoCD applications.

## Overview

By default, the ai-rhdh installer configures RHDH to connect to the local cluster where it's installed. With remote cluster support, you can:

- View Kubernetes resources across multiple clusters
- Monitor Tekton pipelines running on different clusters
- Track ArgoCD applications deployed to remote clusters
- Use software templates that deploy to different target clusters

## New Installation with Remote Clusters

### Prerequisites

For each remote cluster you want to connect:

1. **Service Account**: Create a service account with appropriate permissions
2. **Token**: Generate a service account token 
3. **Cluster Access**: Ensure network connectivity from RHDH to the remote cluster API

### Setting Up Remote Cluster Access

#### Step 1: Connect to Your Remote Cluster

```bash
# List available contexts
kubectl config get-contexts

# Switch to your remote cluster
kubectl config use-context <your-remote-cluster-context>

# Verify you're connected to the right cluster
kubectl cluster-info
```

#### Step 2: Create Service Account and Permissions

```bash
# Create a service account for RHDH access
kubectl create serviceaccount rhdh-remote-access -n default

# Grant view permissions across the cluster
kubectl create clusterrolebinding rhdh-remote-access \
  --clusterrole=view \
  --serviceaccount=default:rhdh-remote-access
```

#### Step 3: Create Service Account Token

For **Kubernetes 1.24+** (tokens are not auto-created):
```bash
# Create a token secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: rhdh-remote-access-token
  namespace: default
  annotations:
    kubernetes.io/service-account.name: rhdh-remote-access
type: kubernetes.io/service-account-token
EOF

# Wait a moment for token to be generated, then retrieve it
kubectl get secret rhdh-remote-access-token -o jsonpath='{.data.token}' | base64 -d
```

#### Step 4: Get Cluster Information

```bash
# Get the cluster API server URL
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'

# Get cluster name (use current context name or choose your own)
kubectl config current-context

# Or create a meaningful name for the cluster
echo "your-cluster-name"  # Use any descriptive name
```

### Installation with Remote Clusters

1. **Install the Helm chart**:
   ```bash
   helm upgrade --install ai-rhdh ./chart --namespace ai-rhdh --create-namespace
   ```

2. **Run configuration with remote cluster prompts**:
   ```bash
   bash ./configure.sh
   ```

3. **When prompted for remote clusters**:
   ```
   **Remote Cluster Configuration**
   You can configure additional clusters for multi-cluster support.
   Use CTRL-D when finished adding clusters.

   === Remote Cluster 1 ===
   Enter remote cluster service account name (CTRL-D to finish): rhdh-remote-access
   Enter remote cluster URL (e.g., https://api.cluster.example.com:6443): https://api.prod.example.com:6443
   Enter remote cluster service account token: eyJhbGciOiJSUzI1NiIsImtpZCI6...
   Enter auth provider (default: serviceAccount): [press Enter]
   Remote cluster 1 configured: rhdh-remote-access (https://api.prod.example.com:6443)

   === Remote Cluster 2 ===
   Enter remote cluster service account name (CTRL-D to finish): [press CTRL-D to finish]

   Configured 1 remote cluster(s)
   ```

## Multiple Clusters Example

Example configuration for 3 clusters in `private.env`:

```bash
export REMOTE_CLUSTER_COUNT=2

# Production cluster
export REMOTE_K8S_SA_1='rhdh-prod-access'
export REMOTE_K8S_URL_1='https://api.prod.example.com:6443'
export REMOTE_K8S_SA_TOKEN_1='eyJhbGciOiJSUzI1NiIsImtpZCI6...'
export REMOTE_K8S_AUTH_PROVIDER_1='serviceAccount'

# Staging cluster  
export REMOTE_K8S_SA_2='rhdh-staging-access'
export REMOTE_K8S_URL_2='https://api.staging.example.com:6443'
export REMOTE_K8S_SA_TOKEN_2='eyJhbGciOiJSUzI1NiIsImtpZCI6...'
export REMOTE_K8S_AUTH_PROVIDER_2='serviceAccount'
```
