resource "aws_iam_role" "this" {
  name = "${var.project_name}-${var.environment}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Federated = var.oidc_provider_arn
      }

      Action = "sts:AssumeRoleWithWebIdentity"

      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"

          "${var.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ebs-csi-role"
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  role = aws_iam_role.this.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "this" {
  cluster_name = var.cluster_name

  addon_name = "aws-ebs-csi-driver"

  service_account_role_arn = aws_iam_role.this.arn

  resolve_conflicts_on_create = "OVERWRITE"

  tags = {
    Name = "${var.project_name}-${var.environment}-ebs-csi"
  }

  depends_on = [
    aws_iam_role_policy_attachment.this
  ]
}