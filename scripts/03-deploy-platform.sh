#!/usr/bin/env bash
set -euo pipefail

# Apply the existing Kubernetes manifests in the order proven by the working
# deployment: namespace, storage, Ollama, Open WebUI, then ALB Ingress.
NAMESPACE="${NAMESPACE:-ai-platform}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-300s}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

MANIFESTS=(
  "kubernetes/namespaces/namespace.yaml"
  "kubernetes/storage/gp3-storageclass.yaml"
  "kubernetes/storage/ollama-pvc.yaml"
  "kubernetes/storage/open-webui-pvc.yaml"
  "kubernetes/ollama/deployment.yaml"
  "kubernetes/openwebui/deployment.yaml"
  "kubernetes/ingress/open-webui-ingress.yaml"
)

command -v kubectl >/dev/null 2>&1 || {
  echo "Error: required command 'kubectl' was not found." >&2
  exit 1
}

for manifest in "${MANIFESTS[@]}"; do
  [[ -f "$REPO_ROOT/$manifest" ]] || {
    echo "Error: missing manifest: $REPO_ROOT/$manifest" >&2
    exit 1
  }
done

echo "Applying namespace and storage manifests..."
for manifest in "${MANIFESTS[@]:0:4}"; do
  kubectl apply -f "$REPO_ROOT/$manifest"
done

echo "Deploying Ollama..."
kubectl apply -f "$REPO_ROOT/${MANIFESTS[4]}"
kubectl rollout status deployment/ollama \
  --namespace "$NAMESPACE" \
  --timeout="$ROLLOUT_TIMEOUT"

echo "Deploying Open WebUI..."
kubectl apply -f "$REPO_ROOT/${MANIFESTS[5]}"
kubectl rollout status deployment/open-webui \
  --namespace "$NAMESPACE" \
  --timeout="$ROLLOUT_TIMEOUT"

echo "Applying the ALB Ingress..."
kubectl apply -f "$REPO_ROOT/${MANIFESTS[6]}"

echo "Platform deployment completed."
kubectl get pods,pvc,services,ingress --namespace "$NAMESPACE"
