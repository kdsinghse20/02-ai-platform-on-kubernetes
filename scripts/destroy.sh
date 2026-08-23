#!/usr/bin/env bash
set -euo pipefail

# Remove only resources managed by Helm/Kubernetes in this scripts layer.
# Terraform remains responsible for destroying AWS/EKS/EBS CSI/IAM resources.
NAMESPACE="${NAMESPACE:-ai-platform}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

command -v kubectl >/dev/null 2>&1 || {
  echo "Error: required command 'kubectl' was not found." >&2
  exit 1
}
command -v helm >/dev/null 2>&1 || {
  echo "Error: required command 'helm' was not found." >&2
  exit 1
}

echo "Deleting Ingress first so its AWS ALB can be cleaned up..."
kubectl delete -f "$REPO_ROOT/kubernetes/ingress/open-webui-ingress.yaml" \
  --ignore-not-found=true \
  --wait=true

echo "Deleting the ai-platform namespace and all namespaced workloads/storage claims..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found=true --wait=true

echo "Deleting the platform StorageClass..."
kubectl delete -f "$REPO_ROOT/kubernetes/storage/gp3-storageclass.yaml" \
  --ignore-not-found=true

if helm status aws-load-balancer-controller --namespace kube-system >/dev/null 2>&1; then
  echo "Uninstalling AWS Load Balancer Controller..."
  helm uninstall aws-load-balancer-controller --namespace kube-system --wait
else
  echo "AWS Load Balancer Controller Helm release is already absent."
fi

kubectl delete -f "$REPO_ROOT/kubernetes/infrastructure/aws-load-balancer-controller/serviceaccount.yaml" \
  --ignore-not-found=true

echo "Kubernetes/Helm resources removed. Run Terraform destroy separately if intended."
