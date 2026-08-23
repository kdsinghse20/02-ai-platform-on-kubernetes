#!/usr/bin/env bash
set -euo pipefail

# Connect kubectl to the Terraform-managed EKS cluster and confirm that the
# Terraform-managed nodes and EBS CSI driver are ready.
REGION="${REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-ai-platform-dev}"

for command in aws kubectl; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Error: required command '$command' was not found." >&2
    exit 1
  }
done

echo "Updating kubeconfig for ${CLUSTER_NAME} in ${REGION}..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

echo "Checking worker nodes..."
kubectl get nodes

echo "Checking the Terraform-managed EBS CSI driver..."
kubectl get csidriver ebs.csi.aws.com
kubectl rollout status deployment/ebs-csi-controller \
  --namespace kube-system \
  --timeout="${ROLLOUT_TIMEOUT:-300s}"

echo "Cluster setup check completed."
