# Reproducible platform scripts

These scripts orchestrate the existing Terraform and Kubernetes layers. Terraform remains responsible for AWS infrastructure, EKS, IAM, and EBS CSI. Kubernetes manifests remain responsible for the namespace, storage, Ollama, Open WebUI, and Ingress.

Defaults can be overridden with environment variables. Run the documented flow
from the repository root: the monitoring and logging scripts use repository-relative
paths, while the core platform scripts resolve their own location.

```bash
export REGION=ap-south-1
export CLUSTER_NAME=ai-platform-dev
export NAMESPACE=ai-platform
export MODEL=gemma3:1b
```

## Rebuild order

First create the AWS infrastructure from the repository's Terraform environment. Then run:

```bash
./scripts/01-setup-cluster.sh
./scripts/02-install-aws-load-balancer-controller.sh
./scripts/03-deploy-platform.sh
kubectl apply -f kubernetes/openwebui/service.yaml
./scripts/04-pull-model.sh
./scripts/verify.sh
```

The explicit Service apply is required because the current platform script applies
the Open WebUI Deployment but does not include its separate Service manifest.

Optional observability layers can then be installed from the repository root:

```bash
./scripts/05-install-monitoring.sh
./scripts/06-install-logging.sh
```

The monitoring stack is functional through `kube-prometheus-stack`. Loki and Alloy
have an install path and baseline configuration, but end-to-end Grafana datasource
wiring and log-query verification are still future work.

To pull a different model, pass its name explicitly:

```bash
./scripts/04-pull-model.sh gemma3:1b
```

The AWS-generated ALB DNS name is never stored in these scripts. `verify.sh` reads the current address from Kubernetes Ingress status. DNS and certificate configuration remain in their existing declarative layers.

## Open WebUI note for `gemma3:1b`

In the working setup, `gemma3:1b` does not support native tool calling. In a new Open WebUI chat, open **Chat Controls → Advanced Params → Function Calling** and select **Legacy**. Then start a fresh chat. This is a UI/runtime setting and is intentionally documented rather than guessed into the Kubernetes manifests.

## Cleanup

```bash
./scripts/destroy.sh
```

This removes the Ingress, the `ai-platform` namespace (including its PVCs), the `gp3` StorageClass, and the Helm-installed AWS Load Balancer Controller. It does not run `terraform destroy`. Deleting PVCs can delete their backing EBS volumes according to the StorageClass reclaim policy, so preserve data before running cleanup if needed.
