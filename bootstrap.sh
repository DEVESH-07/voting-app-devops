#!/usr/bin/env bash

set -e

CLUSTER_NAME="voting-app"
K8S_DIR="my-k8s"

echo "Detecting OS..."

if [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
  HOSTS_FILE="/c/Windows/System32/drivers/etc/hosts"
  echo "Windows detected. Using hosts file: $HOSTS_FILE"

  if [[ ! -w "$HOSTS_FILE" ]]; then
    echo "ERROR: Hosts file is not writable."
    echo "Please run Git Bash as Administrator:"
    echo "Start Menu → Git Bash → Right click → Run as administrator"
    exit 1
  fi
else
  HOSTS_FILE="/etc/hosts"
  echo "Linux/macOS detected. Using hosts file: $HOSTS_FILE"
fi

add_host_entry() {
  local domain="$1"
  local entry="127.0.0.1 $domain"

  if grep -q "$domain" "$HOSTS_FILE"; then
    echo "$domain already exists in hosts file"
  else
    echo "Adding $domain to hosts file..."

    if [[ "$HOSTS_FILE" == "/etc/hosts" && ! -w "$HOSTS_FILE" ]]; then
      echo "$entry" | sudo tee -a "$HOSTS_FILE" > /dev/null
    else
      echo "$entry" >> "$HOSTS_FILE"
    fi
  fi
}

echo "Configuring local hostnames..."
add_host_entry "vote.local"
add_host_entry "result.local"

echo "Deleting old kind cluster if it exists..."
kind delete cluster --name "$CLUSTER_NAME" || true

echo "Creating kind cluster..."
kind create cluster --name "$CLUSTER_NAME" --config kind-config.yaml

echo "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "Waiting for ingress controller to become ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo "Deploying application manifests except ingress..."

for file in "$K8S_DIR"/*.yaml; do
  if [[ "$(basename "$file")" != "ingress.yaml" ]]; then
    echo "Applying $file"
    kubectl apply -f "$file"
  fi
done

echo "Waiting for application pods to become ready..."
kubectl wait --for=condition=ready pod --all --timeout=180s

echo "Waiting a little more for NGINX admission webhook..."
sleep 20

echo "Applying ingress..."
kubectl apply -f "$K8S_DIR/ingress.yaml"

echo ""
echo "Deployment complete!"
echo ""
echo "Open:"
echo "  http://vote.local"
echo "  http://result.local"
echo ""
echo "Useful checks:"
echo "  kubectl get pods"
echo "  kubectl get svc"
echo "  kubectl get ingress"
echo "  kubectl get pvc"