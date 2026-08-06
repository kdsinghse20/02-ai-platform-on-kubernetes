resource "aws_security_group" "eks_cluster" {

  name = "${var.project_name}-${var.environment}-eks-cluster-sg"

  description = "Security Group for EKS Control Plane"

  vpc_id = var.vpc_id

  ingress {

    description = "HTTPS"

    from_port = 443

    to_port = 443

    protocol = "tcp"

    cidr_blocks = [
      "10.0.0.0/16"
    ]
  }

  egress {

    from_port = 0

    to_port = 0

    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-cluster-sg"
  }
}

resource "aws_security_group" "eks_nodes" {

  name = "${var.project_name}-${var.environment}-eks-node-sg"

  description = "Security Group for Worker Nodes"

  vpc_id = var.vpc_id

  ingress {

    from_port = 0

    to_port = 65535

    protocol = "tcp"

    self = true
  }

  ingress {

    from_port = 1025

    to_port = 65535

    protocol = "tcp"

    security_groups = [
      aws_security_group.eks_cluster.id
    ]
  }

  egress {

    from_port = 0

    to_port = 0

    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-node-sg"
  }
}