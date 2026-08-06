resource "aws_eks_cluster" "this" {

  name = "${var.project_name}-${var.environment}"

  role_arn = var.cluster_role_arn

  version = var.kubernetes_version

  vpc_config {

    subnet_ids = var.private_subnet_ids

    security_group_ids = [
      var.cluster_security_group_id
    ]

    endpoint_private_access = true

    endpoint_public_access = true

  }

  #  depends_on = [
  #    var.cluster_role_arn
  #  ]

  tags = {
    Name = "${var.project_name}-${var.environment}"
  }
}

resource "aws_eks_node_group" "this" {

  cluster_name = aws_eks_cluster.this.name

  node_group_name = "${var.project_name}-workers"

  node_role_arn = var.node_role_arn

  subnet_ids = var.private_subnet_ids

  instance_types = [
    var.node_instance_type
  ]

  capacity_type = "ON_DEMAND"

  scaling_config {

    desired_size = 2

    min_size = 2

    max_size = 4

  }

  update_config {

    max_unavailable = 1

  }

  depends_on = [
    aws_eks_cluster.this
  ]

  tags = {
    Name = "${var.project_name}-workers"
  }
}

