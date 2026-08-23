#!/usr/bin/env bash
set -euo pipefail

# MODEL may be passed as the first argument or through the environment.
NAMESPACE="${NAMESPACE:-ai-platform}"
MODEL="${1:-${MODEL:-gemma3:1b}}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-300s}"

command -v kubectl >/dev/null 2>&1 || {
  echo "Error: required command 'kubectl' was not found." >&2
  exit 1
}

kubectl rollout status deployment/ollama \
  --namespace "$NAMESPACE" \
  --timeout="$ROLLOUT_TIMEOUT"

echo "Pulling Ollama model ${MODEL}..."
kubectl exec --namespace "$NAMESPACE" deployment/ollama -- ollama pull "$MODEL"

echo "Installed Ollama models:"
kubectl exec --namespace "$NAMESPACE" deployment/ollama -- ollama list
