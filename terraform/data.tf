data "aws_caller_identity" "this" {}

data "aws_partition" "this" {}

data "aws_region" "this" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks_hardened.cluster_name
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = var.github_token_secret_arn
}
