#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="monitoring"

LOKI_RELEASE="loki"
LOKI_CHART="grafana-community/loki"
LOKI_VALUES="kubernetes/monitoring/loki-values.yaml"

ALLOY_RELEASE="alloy"
ALLOY_CHART="grafana/alloy"
ALLOY_VALUES="kubernetes/monitoring/alloy-values.yaml"

echo "=================================================="
echo "Installing / upgrading logging stack"
echo "Loki + Grafana Alloy"
echo "=================================================="

echo "[1/7] Checking Kubernetes connectivity..."
kubectl cluster-info >/dev/null

echo "[2/7] Ensuring monitoring namespace exists..."
kubectl create namespace "${NAMESPACE}" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

echo "[3/7] Adding Grafana Helm repositories..."

helm repo add grafana \
  https://grafana.github.io/helm-charts \
  --force-update

helm repo add grafana-community \
  https://grafana-community.github.io/helm-charts \
  --force-update

helm repo update

echo "[4/7] Installing Loki..."

helm upgrade --install "${LOKI_RELEASE}" "${LOKI_CHART}" \
  --namespace "${NAMESPACE}" \
  --values "${LOKI_VALUES}" \
  --wait \
  --timeout 10m

echo "[5/7] Installing Grafana Alloy..."

helm upgrade --install "${ALLOY_RELEASE}" "${ALLOY_CHART}" \
  --namespace "${NAMESPACE}" \
  --values "${ALLOY_VALUES}" \
  --wait \
  --timeout 10m

echo "[6/7] Checking pods..."

kubectl get pods -n "${NAMESPACE}"

echo "[7/7] Checking Loki and Alloy resources..."

kubectl get svc -n "${NAMESPACE}" | grep -E "loki|alloy" || true

echo
echo "Logging stack installed successfully."
echo
echo "Useful commands:"
echo
echo "Alloy logs:"
echo "kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/name=alloy --tail=100"
echo
echo "Loki pods:"
echo "kubectl get pods -n ${NAMESPACE} | grep loki"
echo
echo "AI Platform logs should become queryable in Grafana using namespace:"
echo "ai-platform"