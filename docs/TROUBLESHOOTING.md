# Troubleshooting and build lessons

## `03-deploy-platform.sh` finishes but Open WebUI has no Service

The current script applies `kubernetes/openwebui/deployment.yaml` but not the separate Service manifest. Apply it from the repository root:

```bash
kubectl apply -f kubernetes/openwebui/service.yaml
kubectl get service open-webui -n ai-platform
```

Without this Service, the ALB Ingress has no backend to route to.

## A script cannot find a Kubernetes manifest

`05-install-monitoring.sh` and `06-install-logging.sh` use repository-relative paths. Run them from the repository root:

```bash
./scripts/05-install-monitoring.sh
./scripts/06-install-logging.sh
```

The core scripts `01` through `04`, `verify.sh`, and `destroy.sh` resolve their own location and can be invoked using their full path.

## PVC remains `Pending`

Check the CSI driver, StorageClass, events, and pod scheduling:

```bash
kubectl get csidriver ebs.csi.aws.com
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
kubectl get storageclass gp3
kubectl describe pvc -n ai-platform
kubectl describe pod -n ai-platform
```

The StorageClass uses `WaitForFirstConsumer`, so a PVC may remain pending until Kubernetes schedules a consuming pod and can provision the EBS volume in the correct Availability Zone.

## AWS Load Balancer Controller is not ready

```bash
kubectl get deployment aws-load-balancer-controller -n kube-system
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=100
kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o yaml
```

Confirm that the ServiceAccount annotation refers to the IAM role created for this cluster/account. The committed annotation is environment-specific and will not work unchanged in another AWS account.

## ALB hostname is empty

```bash
kubectl describe ingress open-webui -n ai-platform
kubectl get events -n ai-platform --sort-by=.lastTimestamp
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=100
```

Typical causes in this repository's architecture are a missing Open WebUI Service, controller/IRSA errors, incorrect subnet tags, or an invalid certificate ARN.

## HTTPS or DNS does not work

First obtain the current ALB hostname:

```bash
kubectl get ingress open-webui -n ai-platform \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\n"}'
```

Then confirm all four values agree:

1. the host in the Ingress rule
2. the hostname covered by the ACM certificate
3. the ACM certificate region (`ap-south-1` in the current deployment)
4. the Route53 record target

The ALB hostname is generated dynamically. Do not copy an old ALB hostname into rebuild instructions.

## Ollama is running but the model is unavailable

```bash
kubectl exec -n ai-platform deployment/ollama -- ollama list
./scripts/04-pull-model.sh gemma3:1b
kubectl logs -n ai-platform deployment/ollama --tail=100
```

The model is pulled after the Deployment becomes ready and is stored on the Ollama PVC. A new cluster or a deleted PVC requires the model to be pulled again.

## `gemma3:1b` does not chat normally in Open WebUI

In the established setup, open **Chat Controls → Advanced Params → Function Calling**, select **Legacy**, and start a fresh chat. This is currently required for normal chat with `gemma3:1b`; the default/native function-calling behavior is not compatible with this setup.

## Monitoring pods do not become ready

```bash
kubectl get pods,pvc -n monitoring
kubectl describe pod -n monitoring
kubectl get events -n monitoring --sort-by=.lastTimestamp
```

The monitoring stack adds CPU, memory, and EBS demand. The default node group has two `t3.large` nodes; scheduling failures may indicate insufficient available capacity rather than a chart error.

## Loki is installed but logs are not visible in Grafana

The repository provides Loki and Alloy installation/configuration, but it does not provision Loki as a Grafana datasource or include an end-to-end query test. Inspect the current components:

```bash
kubectl get pods,svc,pvc -n monitoring
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy --tail=100
kubectl get pods -n monitoring | grep loki
```

Completing datasource provisioning, verifying ingestion/querying, and tuning retention/relabeling remain future work.

## Destroy is blocked by AWS resources

Remove controller-managed resources while the cluster and controllers still exist. In particular, delete the Ingress and wait for ALB cleanup before destroying EKS. Delete namespaces/PVCs while the EBS CSI driver can remove their backing volumes.

The safe ownership order is:

```text
Helm logging/monitoring releases
  -> monitoring namespace and PVCs
  -> application Ingress/workloads/PVCs and ALB Controller
  -> Terraform-managed EKS/VPC/IAM resources
```

After destruction, confirm that no ALB, NAT gateway, EC2 node, or unexpected EBS volume remains billable.
