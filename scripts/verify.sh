#!/usr/bin/env bash
set -euo pipefail

# Read-only checks for the cluster, storage, workloads, controller, model API,
# and dynamically assigned ALB address.
NAMESPACE="${NAMESPACE:-ai-platform}"
MODEL="${MODEL:-gemma3:1b}"

command -v kubectl >/dev/null 2>&1 || {
  echo "Error: required command 'kubectl' was not found." >&2
  exit 1
}

echo "Nodes:"
kubectl get nodes

echo "EBS CSI driver:"
kubectl get csidriver ebs.csi.aws.com
kubectl get deployment ebs-csi-controller --namespace kube-system
kubectl get daemonset ebs-csi-node --namespace kube-system

echo "AWS Load Balancer Controller:"
kubectl get deployment aws-load-balancer-controller --namespace kube-system

echo "Platform resources:"
kubectl get pods,pvc,services,ingress --namespace "$NAMESPACE"

echo "Installed Ollama models:"
kubectl exec --namespace "$NAMESPACE" deployment/ollama -- ollama list

echo "Testing the Ollama API from inside the cluster..."
TEST_POD="ollama-api-check-${RANDOM}"
API_RESPONSE="$(kubectl run "$TEST_POD" \
  --namespace "$NAMESPACE" \
  --rm \
  --stdin \
  --restart=Never \
  --image=curlimages/curl \
  --command -- curl --fail --silent http://ollama:11434/api/tags)"

if [[ "$API_RESPONSE" != *"\"name\":\"$MODEL\""* ]]; then
  echo "Error: Ollama API responded, but model '$MODEL' was not listed." >&2
  exit 1
fi
echo "Ollama API is healthy and lists ${MODEL}."

# Never hardcode the generated hostname: read it from Ingress status.
ALB_ADDRESS="$(kubectl get ingress open-webui \
  --namespace "$NAMESPACE" \
  --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

if [[ -n "$ALB_ADDRESS" ]]; then
  echo "Current ALB address: $ALB_ADDRESS"
else
  echo "ALB address is not assigned yet. Inspect with:"
  echo "  kubectl describe ingress open-webui -n $NAMESPACE"
  exit 1
fi

echo "Verification completed."
