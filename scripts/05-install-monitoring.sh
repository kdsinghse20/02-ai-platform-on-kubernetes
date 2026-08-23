#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="monitoring"
RELEASE_NAME="kube-prometheus-stack"
CHART="prometheus-community/kube-prometheus-stack"
VALUES_FILE="kubernetes/monitoring/kube-prometheus-stack-values.yaml"

echo "=================================================="
echo "Installing / upgrading monitoring stack"
echo "=================================================="

echo "[1/5] Checking kubectl connectivity..."
kubectl cluster-info >/dev/null

echo "[2/5] Creating monitoring namespace..."
kubectl apply -f kubernetes/monitoring/namespace.yaml

echo "[3/5] Adding Prometheus Helm repository..."
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts \
  --force-update

helm repo update

echo "[4/5] Installing kube-prometheus-stack..."

helm upgrade --install "${RELEASE_NAME}" "${CHART}" \
  --namespace "${NAMESPACE}" \
  --values "${VALUES_FILE}" \
  --wait \
  --timeout 10m

echo "[5/5] Verifying monitoring components..."

kubectl get pods -n "${NAMESPACE}"
kubectl get pvc -n "${NAMESPACE}"
kubectl get svc -n "${NAMESPACE}"

echo
echo "Monitoring stack installed successfully."
echo
echo "Grafana admin password:"
kubectl get secret \
  -n "${NAMESPACE}" \
  "${RELEASE_NAME}-grafana" \
  -o jsonpath="{.data.admin-password}" \
  | base64 --decode

echo
echo
echo "For local Grafana access:"
echo "kubectl port-forward -n ${NAMESPACE} svc/${RELEASE_NAME}-grafana 3000:80"
echo
echo "Then open: http://localhost:3000"