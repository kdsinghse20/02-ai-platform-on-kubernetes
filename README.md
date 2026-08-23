# AI Platform on Kubernetes

A learning-focused, reproducible platform for running a local large language model on Amazon EKS. The repository combines Terraform-managed AWS infrastructure with Kubernetes workloads, persistent EBS storage, HTTPS ingress, and a basic observability stack.

The project demonstrates rapid learning and adaptation across AI runtime and platform engineering concerns: provisioning the cluster, exposing a user interface securely, persisting models and application state, validating the deployment, and tearing the environment down when it is not needed. It is a portfolio/reference implementation, not a claim of production readiness or production AI-platform experience.

## What is implemented

- A multi-AZ VPC in `ap-south-1`, with public, private application, and private AI subnets plus one NAT gateway per public subnet
- Amazon EKS `1.33` with a managed node group of two `t3.large` on-demand nodes by default
- IAM roles and IRSA for the EBS CSI driver and AWS Load Balancer Controller
- Ollama and Open WebUI as single-replica Kubernetes Deployments
- `gp3` EBS-backed persistent volumes for Ollama models and Open WebUI data
- An internet-facing Application Load Balancer with HTTP-to-HTTPS redirect
- An existing ACM certificate and Route53 hostname (`chat.kdsingh.cc`) referenced by the Ingress
- Prometheus, Alertmanager, and Grafana through `kube-prometheus-stack`
- Initial Loki and Grafana Alloy configuration; end-to-end log querying is not yet considered complete
- Ordered setup, deployment, model-pull, verification, monitoring, logging, and cleanup scripts

## Architecture

```text
User
  |
  | HTTPS: chat.kdsingh.cc
  v
Route53 record -> AWS ALB -> Open WebUI Service -> Open WebUI Pod
                                                   |
                                                   | http://ollama:11434
                                                   v
                                               Ollama Service -> Ollama Pod

AWS / EKS foundation
  Terraform -> VPC, subnets, NAT gateways, IAM, EKS, managed nodes,
               OIDC/IRSA, EBS CSI add-on, ALB Controller IAM role

Persistent data
  Open WebUI PVC (100 GiB) -> gp3 StorageClass -> EBS volume
  Ollama PVC     (100 GiB) -> gp3 StorageClass -> EBS volume

Observability namespace
  kube-prometheus-stack -> Prometheus (20 GiB), Grafana (10 GiB),
                           Alertmanager (5 GiB)
  Alloy -> Loki gateway -> monolithic Loki filesystem storage (20 GiB)
                           [configuration present; end-to-end validation pending]
```

See [Architecture and design notes](docs/ARCHITECTURE.md) for component boundaries and the decisions reflected in the repository.

## Technology stack

| Area | Repository implementation |
| --- | --- |
| Cloud | AWS: VPC, EKS, EC2 managed node group, EBS, IAM, ALB, ACM, Route53 |
| Infrastructure as Code | Terraform `>= 1.8`, AWS provider `~> 6.0` |
| Kubernetes | EKS `1.33`; plain Kubernetes manifests |
| AI runtime | `ollama/ollama:latest`; default model pulled by script is `gemma3:1b` |
| User interface | `ghcr.io/open-webui/open-webui:main` |
| Storage | AWS EBS CSI add-on, `gp3`, `ReadWriteOnce`, `ext4` |
| Ingress | AWS Load Balancer Controller installed with Helm; ALB Ingress |
| Metrics | `kube-prometheus-stack`: Prometheus, Alertmanager, Grafana |
| Logs | Loki in monolithic mode with filesystem storage; Grafana Alloy pod discovery |

The two application images and Helm charts are not pinned in the current repository. Rebuilds may therefore receive newer upstream versions. Pinning them is a recommended future hardening step.

## Repository structure

```text
.
├── kubernetes/
│   ├── infrastructure/aws-load-balancer-controller/  # IRSA ServiceAccount
│   ├── ingress/                                       # Open WebUI ALB Ingress
│   ├── monitoring/                                    # metrics and logging values
│   ├── namespaces/                                    # ai-platform namespace
│   ├── ollama/                                        # Ollama Deployment and Service
│   ├── openwebui/                                     # Open WebUI Deployment and Service
│   └── storage/                                       # gp3 StorageClass and PVCs
├── scripts/                                           # ordered operational scripts
└── terraform/
    ├── environments/dev/                              # deployable dev environment
    └── modules/                                       # VPC, EKS, IAM, SG, EBS CSI, ALB IAM
```

The `.github/workflows`, `argocd`, `helm`, and several other directories currently contain placeholders only. They are not part of the deployed path described here.

## Prerequisites

- An AWS account and AWS CLI credentials with permission to manage the resources in the Terraform configuration
- `terraform`, `aws`, `kubectl`, and `helm` available locally
- An existing S3 backend bucket matching `terraform/environments/dev/backend.tf`, or a deliberate backend change before `terraform init`
- The ACM certificate ARN and hostname in `kubernetes/ingress/open-webui-ingress.yaml` updated for the target AWS account/domain if this is not the original environment
- A Route53 hosted zone for the chosen domain; after the ALB is created, its record must point to the ALB

Default values used by the repository:

```bash
export REGION=ap-south-1
export CLUSTER_NAME=ai-platform-dev
export NAMESPACE=ai-platform
export MODEL=gemma3:1b
```

## Deploy or rebuild

Run these commands from the repository root.

### 1. Create the AWS and EKS foundation

Review the account-specific backend and Ingress values before applying.

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
cd ../../..
```

Terraform creates the networking, EKS cluster and nodes, OIDC provider, IAM roles, and EBS CSI add-on. The AWS Load Balancer Controller itself is installed in the next step; Terraform creates its IAM role and policy.

### 2. Connect to the cluster and deploy the core platform

```bash
./scripts/01-setup-cluster.sh
./scripts/02-install-aws-load-balancer-controller.sh
./scripts/03-deploy-platform.sh
kubectl apply -f kubernetes/openwebui/service.yaml
./scripts/04-pull-model.sh gemma3:1b
./scripts/verify.sh
```

The separate `kubectl apply` is required by the current repository because `03-deploy-platform.sh` applies the Open WebUI Deployment but does not include `kubernetes/openwebui/service.yaml` in its manifest list.

The scripts are idempotent where they use `apply` or `helm upgrade --install`. The model and both applications use persistent volumes, so pod replacement does not normally require downloading the model again or recreating Open WebUI state while the PVCs remain.

### 3. Install monitoring

```bash
./scripts/05-install-monitoring.sh
```

The script installs `kube-prometheus-stack` into `monitoring` with seven-day Prometheus retention and persistent `gp3` volumes for Prometheus, Grafana, and Alertmanager.

Retrieve the generated Grafana password and open a local tunnel:

```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 --decode
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Open `http://localhost:3000`. The repository currently relies on the dashboards supplied by the chart; no custom AI-platform dashboard is committed.

### 4. Optional: install the current logging baseline

```bash
./scripts/06-install-logging.sh
```

This installs a single-replica, monolithic Loki with filesystem storage and Grafana Alloy for Kubernetes pod discovery and log forwarding. The manifests and install flow exist, but automatic Grafana datasource provisioning and a verified end-to-end log query are not present. Treat this as a baseline under development, not a completed logging solution.

## Access Open WebUI

Get the ALB hostname assigned to the Ingress:

```bash
kubectl get ingress open-webui -n ai-platform \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\n"}'
```

The committed Ingress expects `https://chat.kdsingh.cc`. Route53 must contain an Alias record (or equivalent supported record) for that hostname pointing to the current ALB, and the ACM certificate referenced by the Ingress must be valid in `ap-south-1` for the hostname.

Open the HTTPS URL, create the initial Open WebUI account, select `gemma3:1b`, and start a chat.

> **Required setting for `gemma3:1b`:** in this setup, normal chat currently requires **Open WebUI → Chat Controls → Advanced Params → Function Calling → Legacy**. Start a fresh chat after changing the setting. Native/default function calling does not work correctly with this model in the established deployment.

## Verify the platform

The repository's read-only verification script checks nodes, EBS CSI, AWS Load Balancer Controller, namespaced resources, installed Ollama models, the in-cluster Ollama API, and the assigned ALB hostname:

```bash
./scripts/verify.sh
```

Useful focused checks:

```bash
kubectl get pods,pvc,svc,ingress -n ai-platform
kubectl get storageclass gp3
kubectl exec -n ai-platform deployment/ollama -- ollama list
kubectl get pods,pvc,svc -n monitoring
kubectl describe ingress open-webui -n ai-platform
```

## Persistence behavior

The `gp3` StorageClass uses the EBS CSI driver, `WaitForFirstConsumer`, volume expansion, and a `Delete` reclaim policy. Ollama models and Open WebUI data each request `100Gi` with `ReadWriteOnce`. Monitoring requests an additional `35Gi`; Loki requests `20Gi` when logging is installed.

Deleting and recreating a Pod or Deployment preserves data while its PVC remains. Deleting the `ai-platform` or `monitoring` namespace deletes its PVCs, and the `Delete` reclaim policy normally removes the backing EBS volumes. Back up anything important before cleanup.

## Cost-conscious destroy and rebuild

This environment includes recurring-cost resources such as an EKS control plane, two on-demand EC2 nodes, two NAT gateways, an ALB, and EBS volumes. Destroy the lab when it is not in use.

Delete Kubernetes-created AWS resources before Terraform so their controllers can finish cleanup:

```bash
# Optional observability releases, if installed
helm uninstall alloy -n monitoring --wait
helm uninstall loki -n monitoring --wait
helm uninstall kube-prometheus-stack -n monitoring --wait
kubectl delete namespace monitoring --ignore-not-found=true --wait=true

# Core workloads, PVCs, ALB Ingress, StorageClass, and ALB Controller
./scripts/destroy.sh

# Terraform-owned AWS resources
cd terraform/environments/dev
terraform destroy
```

Confirm that the ALB and EBS volumes have been removed in AWS after cleanup. The script intentionally does not run `terraform destroy`, so infrastructure deletion remains an explicit operator decision.

## Troubleshooting and lessons learned

See [Troubleshooting and build lessons](docs/TROUBLESHOOTING.md). The most important lessons from this implementation are:

- resource ownership and deletion order matter: remove Ingress/PVC-backed workloads before destroying the cluster
- IRSA connects in-cluster controllers to narrowly scoped AWS permissions
- `WaitForFirstConsumer` helps EBS volumes bind in the same Availability Zone as their scheduled pod
- ALB hostnames are dynamic and should be read from Ingress status, not hardcoded
- DNS, certificate region, Ingress host, and certificate ARN must agree for HTTPS to work
- unpinned images/charts reduce rebuild determinism
- lightweight local models may require UI-specific compatibility settings

## Future enhancements

The following are intentionally optional and are not represented as current features:

- Build a custom Grafana dashboard for Ollama/Open WebUI workload health, resource usage, latency, and storage
- Complete Loki end-to-end validation, provision the Grafana datasource, define retention, and tune Alloy relabeling and resource usage
- Add Karpenter for workload-aware node provisioning and cost optimization
- Add GitHub Actions for formatting, validation, security checks, and controlled deployment workflows
- Implement Argo CD/GitOps using the current placeholder directories
- Pin application images and Helm chart versions; add automated upgrade testing
- Replace environment-specific ARNs and hostnames with configuration inputs or generated outputs
- Add secrets management, network policies, Pod security controls, backups, and restore testing
- Add autoscaling, disruption budgets, higher availability, and capacity planning where justified
- Evaluate GPU-backed nodes and larger models as a separate, cost-governed profile

## Scope statement

This repository is a learning and portfolio project. It demonstrates a reproducible Kubernetes-based local LLM platform and the ability to learn and integrate unfamiliar AI-platform components quickly. Production readiness would require additional work across security, availability, release management, backups, observability, performance, and operational governance.
