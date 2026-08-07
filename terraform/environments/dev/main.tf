module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment

  vpc_name = "${var.project_name}-${var.environment}"

  vpc_cidr = "10.0.0.0/16"

  public_subnet_cidrs = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  private_app_subnet_cidrs = [
    "10.0.10.0/24",
    "10.0.11.0/24"
  ]

  private_ai_subnet_cidrs = [
    "10.0.20.0/24",
    "10.0.21.0/24"
  ]
}

module "iam" {

  source = "../../modules/iam"

  project_name = var.project_name

  environment = var.environment

}

module "security_groups" {

  source = "../../modules/security-groups"

  project_name = var.project_name

  environment = var.environment

  vpc_id = module.vpc.vpc_id

}

module "eks" {

  source = "../../modules/eks"

  project_name = var.project_name

  environment = var.environment

  cluster_role_arn = module.iam.cluster_role_arn

  node_role_arn = module.iam.node_role_arn

  private_subnet_ids = concat(
    module.vpc.private_app_subnet_ids,
    module.vpc.private_ai_subnet_ids
  )

  cluster_security_group_id = module.security_groups.cluster_security_group_id

  node_security_group_id = module.security_groups.node_security_group_id

}

data "tls_certificate" "eks" {
  url = module.eks.oidc_issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url = module.eks.oidc_issuer

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.eks.certificates[0].sha1_fingerprint
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-oidc"
  }
}

module "aws_load_balancer_controller" {
  source = "../../modules/aws-load-balancer-controller"

  project_name = var.project_name
  environment  = var.environment
}
