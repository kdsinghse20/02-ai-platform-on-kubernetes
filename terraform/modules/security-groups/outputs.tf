output "cluster_security_group_id" {

  value = aws_security_group.eks_cluster.id

}

output "node_security_group_id" {

  value = aws_security_group.eks_nodes.id

}