namespace=${NAMESPACE:-"ai-rhdh"}
host=$(kubectl get dns cluster -o jsonpath='{.spec.baseDomain}')
baseUrl="https://backstage-ai-rh-developer-hub-$namespace.apps.$host"

helm upgrade --install ai-rhdh ./chart --namespace $namespace --create-namespace --set developer-hub.baseUrl=$baseUrl

echo "RHDH running at: $baseUrl"