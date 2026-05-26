# ---------------------------------------------------------------------------
# Secure Software Factory — Terraform Orchestrator
# Zero-Trust | SAMA Compliant | Modular | Environment-Aware
# ---------------------------------------------------------------------------

locals {
  naming_prefix = "${var.project_name}-${var.environment}"
  is_prod       = var.environment == "prod"
}

# ---------------------------------------------------------------------------
# Module: Networking
# ---------------------------------------------------------------------------
module "networking" {
  source = "./modules/networking"

  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  az_count            = var.az_count
  enable_vpc_endpoints = var.enable_vpc_endpoints
  flow_log_retention  = var.flow_log_retention
  common_tags         = var.common_tags
}

# ---------------------------------------------------------------------------
# Module: EKS Hardened
# ---------------------------------------------------------------------------
module "eks_hardened" {
  source = "./modules/eks_hardened"

  project_name                   = var.project_name
  environment                    = var.environment
  cluster_version                = var.cluster_version
  node_os                        = var.node_os
  enable_guardduty_eks           = var.enable_guardduty_eks
  cluster_endpoint_public_access = var.cluster_endpoint_public_access
  subnet_ids                     = module.networking.private_subnet_ids
  vpc_id                         = module.networking.vpc_id
  common_tags                    = var.common_tags

  depends_on = [module.networking]
}

# ---------------------------------------------------------------------------
# Module: ECR Secure
# ---------------------------------------------------------------------------
module "ecr_secure" {
  source = "./modules/ecr_secure"

  project_name             = var.project_name
  environment              = var.environment
  repositories_list        = var.repositories_list
  enable_enhanced_scanning = var.enable_enhanced_scanning
  replication_region       = var.dr_region
  kms_key_arn              = module.signing_infrastructure.kms_key_arn
  eks_cluster_role_arns    = [module.eks_hardened.cluster_role_arn]
  common_tags              = var.common_tags
}

# ---------------------------------------------------------------------------
# Module: Signing Infrastructure
# ---------------------------------------------------------------------------
module "signing_infrastructure" {
  source = "./modules/signing_infrastructure"

  project_name             = var.project_name
  environment              = var.environment
  kms_key_alias            = var.kms_key_alias
  enable_keyless_signing   = var.enable_keyless_signing
  github_oidc_provider_arn = var.github_oidc_provider_arn
  github_org               = var.github_org
  common_tags              = var.common_tags
}

# ---------------------------------------------------------------------------
# Module: Secrets Management
# ---------------------------------------------------------------------------
module "secrets_management" {
  source = "./modules/secrets_management"

  project_name         = var.project_name
  environment          = var.environment
  rotation_days_db     = var.rotation_days_db
  rotation_days_api    = var.rotation_days_api
  enable_csi_driver    = var.enable_csi_driver
  enable_external_secrets = var.enable_external_secrets
  eks_cluster_name     = module.eks_hardened.cluster_name
  eks_oidc_issuer_url  = module.eks_hardened.oidc_issuer_url
  common_tags          = var.common_tags
}

# ---------------------------------------------------------------------------
# Module: Kyverno Policies
# ---------------------------------------------------------------------------
module "kyverno_policies" {
  source = "./modules/kyverno_policies"

  project_name        = var.project_name
  environment         = var.environment
  kyverno_version     = var.kyverno_version
  enable_policy_reports = var.enable_policy_reports
  signature_key_type  = var.signature_key_type
  kms_key_arn         = module.signing_infrastructure.kms_key_arn
  eks_cluster_name    = module.eks_hardened.cluster_name
  common_tags         = var.common_tags

  depends_on = [module.eks_hardened]
}

# ---------------------------------------------------------------------------
# Module: Runtime Security (Falco)
# ---------------------------------------------------------------------------
module "runtime_security" {
  source = "./modules/runtime_security"

  project_name         = var.project_name
  environment          = var.environment
  falco_version        = var.falco_version
  falcosidekick_enabled = var.falcosidekick_enabled
  alert_sns_topic_arn  = var.alert_sns_topic_arn
  enable_auto_response = var.enable_auto_response
  eks_cluster_name     = module.eks_hardened.cluster_name
  common_tags          = var.common_tags

  depends_on = [module.kyverno_policies]
}

# ---------------------------------------------------------------------------
# Module: GitHub Runners
# ---------------------------------------------------------------------------
module "github_runners" {
  source = "./modules/github_runners"

  project_name            = var.project_name
  environment             = var.environment
  github_org              = var.github_org
  github_app_id_secret_arn = var.github_token_secret_arn
  runner_min_replicas     = var.runner_min_replicas
  runner_max_replicas     = var.runner_max_replicas
  runner_namespace        = "github-runners"
  eks_cluster_name        = module.eks_hardened.cluster_name
  eks_oidc_issuer_url     = module.eks_hardened.oidc_issuer_url
  subnet_ids              = module.networking.private_subnet_ids
  common_tags             = var.common_tags

  depends_on = [module.kyverno_policies]
}

# ---------------------------------------------------------------------------
# Module: SBOM Platform (Dependency-Track)
# ---------------------------------------------------------------------------
module "sbom_platform" {
  source = "./modules/sbom_platform"

  project_name               = var.project_name
  environment                = var.environment
  dependency_track_version   = var.dependency_track_version
  db_instance_class          = var.db_instance_class
  sbom_bucket_name           = var.sbom_bucket_name
  enable_license_analysis    = var.enable_license_analysis
  subnet_ids                 = module.networking.private_subnet_ids
  vpc_id                     = module.networking.vpc_id
  eks_cluster_name           = module.eks_hardened.cluster_name
  eks_oidc_issuer_url        = module.eks_hardened.oidc_issuer_url
  common_tags                = var.common_tags
}

# ---------------------------------------------------------------------------
# Module: Observability & Security Dashboards
# ---------------------------------------------------------------------------
module "observability_sec" {
  source = "./modules/observability_sec"

  project_name                     = var.project_name
  environment                      = var.environment
  grafana_admin_password_secret    = var.grafana_admin_password_secret
  pagerduty_service_key_secret_arn = var.pagerduty_service_key_secret_arn
  mttp_threshold_days              = var.mttp_threshold_days
  enable_security_dashboards       = var.enable_security_dashboards
  eks_cluster_name                 = module.eks_hardened.cluster_name
  subnet_ids                       = module.networking.private_subnet_ids
  common_tags                      = var.common_tags
}
