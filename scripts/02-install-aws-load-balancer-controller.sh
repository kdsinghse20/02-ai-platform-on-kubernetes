#!/usr/bin/env bash
set -euo pipefail

# Terraform owns the controller IAM role. This script applies its existing
# IRSA ServiceAccount and installs/upgrades the in-cluster Helm release.
REGION="${REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-ai-platform-dev}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-300s}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SERVICE_ACCOUNT_MANIFEST="$REPO_ROOT/kubernetes/infrastructure/aws-load-balancer-controller/serviceaccount.yaml"

for command in aws kubectl helm; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Error: required command '$command' was not found." >&2
    exit 1
  }
done

[[ -f "$SERVICE_ACCOUNT_MANIFEST" ]] || {
  echo "Error: missing manifest: $SERVICE_ACCOUNT_MANIFEST" >&2
  exit 1
}

VPC_ID="$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --query 'cluster.resourcesVpcConfig.vpcId' \
  --output text)"

if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
  echo "Error: could not determine the VPC ID for $CLUSTER_NAME." >&2
  exit 1
fi

echo "Applying the Terraform-backed IRSA ServiceAccount..."
kubectl apply -f "$SERVICE_ACCOUNT_MANIFEST"

echo "Adding/updating the EKS Helm repository..."
if ! helm repo add eks https://aws.github.io/eks-charts 2>/dev/null; then
  helm repo add eks https://aws.github.io/eks-charts --force-update
fi
helm repo update eks

echo "Installing/upgrading AWS Load Balancer Controller for VPC ${VPC_ID}..."
helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set "clusterName=$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set "region=$REGION" \
  --set "vpcId=$VPC_ID" \
  --wait \
  --timeout "$ROLLOUT_TIMEOUT"

kubectl rollout status deployment/aws-load-balancer-controller \
  --namespace kube-system \
  --timeout="$ROLLOUT_TIMEOUT"

echo "AWS Load Balancer Controller is ready."
