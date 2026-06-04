$ErrorActionPreference = "Stop"

$CLUSTER_NAME = "voting-app"

Write-Host "Deleting old kind cluster if it exists..."
kind delete cluster --name $CLUSTER_NAME 2>$null

Write-Host "Creating kind cluster..."
kind create cluster --name $CLUSTER_NAME --config kind-config.yaml

Write-Host "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

Write-Host "Waiting for ingress controller to become ready..."
kubectl wait --namespace ingress-nginx `
  --for=condition=ready pod `
  --selector=app.kubernetes.io/component=controller `
  --timeout=180s

Write-Host "Deploying voting app..."
kubectl apply -f my-k8s/

Write-Host "Waiting for application pods to become ready..."
kubectl wait --for=condition=ready pod --all --timeout=180s

Write-Host ""
Write-Host "Deployment complete!"
Write-Host ""
Write-Host "Open:"
Write-Host "  http://vote.local"
Write-Host "  http://result.local"
Write-Host ""
Write-Host "If these do not open, add this to hosts file:"
Write-Host "127.0.0.1 vote.local"
Write-Host "127.0.0.1 result.local"
Write-Host ""
Write-Host "Useful checks:"
Write-Host "kubectl get pods"
Write-Host "kubectl get svc"
Write-Host "kubectl get ingress"
Write-Host "kubectl get pvc"

