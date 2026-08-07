resource "aws_iam_policy" "this" {
  name        = "${var.project_name}-${var.environment}-aws-load-balancer-controller"
  description = "IAM policy for AWS Load Balancer Controller"

  policy = file("${path.module}/iam-policy.json")

  tags = {
    Name = "${var.project_name}-${var.environment}-aws-load-balancer-controller"
  }
}