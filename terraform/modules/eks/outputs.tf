output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "oidc_issuer" {
  description = "EKS OIDC issuer URL"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "cluster_endpoint" {

  value = aws_eks_cluster.this.endpoint

}

output "cluster_ca" {

  value = aws_eks_cluster.this.certificate_authority[0].data

}