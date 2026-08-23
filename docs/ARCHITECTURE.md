# Architecture and design notes

## Platform flow

The platform separates AWS infrastructure ownership from Kubernetes workload ownership:

1. Terraform creates the VPC, subnets, routing, NAT gateways, EKS cluster, managed node group, IAM roles, OIDC provider, EBS CSI add-on, and AWS Load Balancer Controller IAM policy/role.
2. A Kubernetes ServiceAccount binds the AWS Load Balancer Controller to its Terraform-created IAM role through IRSA.
3. Helm installs the AWS Load Balancer Controller into `kube-system`.
4. Plain manifests create the `ai-platform` namespace, `gp3` StorageClass, PVCs, Ollama, Open WebUI, and the ALB Ingress.
5. Ollama is reachable only through the cluster-internal `ollama` Service. Open WebUI uses `OLLAMA_BASE_URL=http://ollama:11434`.
6. Open WebUI is exposed through a cluster-internal Service and an internet-facing ALB. The Ingress redirects HTTP to HTTPS using an existing ACM certificate.

## Network layout

The dev environment uses `10.0.0.0/16` across two Availability Zones:

- public subnets: `10.0.1.0/24`, `10.0.2.0/24`
- private application subnets: `10.0.10.0/24`, `10.0.11.0/24`
- private AI subnets: `10.0.20.0/24`, `10.0.21.0/24`

EKS nodes are placed across the combined private application and private AI subnet lists. Public subnets carry the Kubernetes public-ELB tags used by the internet-facing ALB. Each public subnet has a NAT gateway, and corresponding private subnets route outbound traffic through it.

The EKS API endpoint has both public and private access enabled in the current Terraform module.

## Compute and workloads

The default managed node group has two on-demand `t3.large` nodes, can scale between two and four nodes, uses the `AL2023_x86_64_STANDARD` AMI type, and assigns a 100 GiB node disk.

Both AI workloads are single replicas:

| Workload | Requests | Limits | Persistent mount |
| --- | --- | --- | --- |
| Ollama | 500m CPU, 2 GiB | 2 CPU, 8 GiB | `/root/.ollama` |
| Open WebUI | 250m CPU, 1 GiB | 1 CPU, 4 GiB | `/app/backend/data` |

This CPU-oriented configuration is suitable for learning with a small model such as `gemma3:1b`. It is not a benchmarked high-throughput or highly available inference design.

## Storage

Terraform installs the AWS EBS CSI add-on with an IRSA role using the AWS-managed `AmazonEBSCSIDriverPolicy`. Kubernetes defines one `gp3` StorageClass:

- provisioner: `ebs.csi.aws.com`
- filesystem: `ext4`
- binding: `WaitForFirstConsumer`
- expansion: enabled
- reclaim policy: `Delete`

Ollama and Open WebUI each request a 100 GiB `ReadWriteOnce` volume. The monitoring values request 10 GiB for Grafana, 20 GiB for Prometheus, and 5 GiB for Alertmanager. Loki requests 20 GiB when installed.

## Ingress, DNS, and TLS

The `open-webui` Ingress uses `ingressClassName: alb`, IP targets, an internet-facing scheme, and listeners on ports 80 and 443. The controller redirects HTTP traffic to HTTPS and forwards traffic to the `open-webui` Service on port 80.

The committed manifest contains an environment-specific ACM certificate ARN and the host `chat.kdsingh.cc`. Route53 configuration is not managed by Terraform in this repository. For another account or domain, update the certificate ARN and host, apply the Ingress, then point the Route53 record at the ALB hostname reported in Ingress status.

## Observability status

`05-install-monitoring.sh` installs `kube-prometheus-stack` in `monitoring`. The values enable persistent Grafana storage, seven-day Prometheus retention, persistent Prometheus and Alertmanager storage, and explicit resource requests/limits. The stack supplies its standard Kubernetes dashboards; a custom AI-platform dashboard has not been added.

`06-install-logging.sh` installs Loki and Grafana Alloy. Loki is configured as one monolithic replica with TSDB schema v13, filesystem storage, no authentication, and a gateway. Alloy discovers Kubernetes pods, adds namespace/pod/container labels, reads pod logs, and writes to the Loki gateway.

The repository does not contain Grafana datasource provisioning for Loki, an end-to-end verification query, retention tuning, or production-grade object storage. For that reason, logging is documented as an initial implementation whose end-to-end functionality still needs completion and tuning.

## Current boundaries

- No Argo CD/GitOps deployment is implemented; its directories contain placeholders.
- No GitHub Actions workflow is implemented.
- No Karpenter or GPU node group is implemented.
- No custom Grafana dashboard is committed.
- No external secrets, network policies, backups, autoscaling, or multi-replica application design is present.
- Ollama and Open WebUI images use moving tags, and Helm chart versions are not pinned.
