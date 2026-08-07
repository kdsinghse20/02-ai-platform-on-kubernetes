output "policy_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM policy"
  value       = aws_iam_policy.this.arn
}

output "policy_name" {
  description = "Name of the AWS Load Balancer Controller IAM policy"
  value       = aws_iam_policy.this.name
}

output "iam_role_arn" {
  value = aws_iam_role.this.arn
}