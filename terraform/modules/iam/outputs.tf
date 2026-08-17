output "cluster_role_arn" {

  value = aws_iam_role.eks_cluster.arn

}

output "node_role_arn" {

  value = aws_iam_role.eks_nodes.arn

}

output "ebs_csi_role_arn" {
  value = aws_iam_role.ebs_csi.arn
}