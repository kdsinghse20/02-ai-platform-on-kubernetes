output "role_arn" {
  value = aws_iam_role.this.arn
}

output "addon_name" {
  value = aws_eks_addon.this.addon_name
}