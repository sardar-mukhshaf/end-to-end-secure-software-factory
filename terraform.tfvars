# ---------------------------------------------------------------------------
# Global Terraform Variables — Secure Software Factory
# Fill in all values before deployment. No defaults for sensitive data.
# ---------------------------------------------------------------------------

project_name = "ssf"
environment  = "dev"
aws_region   = "me-central-1"
dr_region    = "me-south-1"

security_level = "hardened"

common_tags = {
  Project     = "secure-software-factory"
  CostCenter  = "security"
  Compliance  = "SAMA-CSF"
  Owner       = "devsecops-team"
}

# GitHub Configuration
github_org              = "your-github-org"
github_token_secret_arn = "arn:aws:secretsmanager:me-central-1:123456789012:secret:github-token"

# MTTP Threshold
mttp_threshold_days = 7

# Networking
vpc_cidr  = "10.0.0.0/16"
az_count  = 3

# ECR Repositories (one per microservice)
repositories_list = [
  "payment-service",
  "auth-service",
  "notification-service",
  "reporting-service",
]

# EKS
cluster_version                = "1.29"
node_os                        = "bottlerocket"
enable_guardduty_eks           = true
cluster_endpoint_public_access = false

# Kyverno
kyverno_version       = "3.2.0"
enable_policy_reports = true
signature_key_type    = "kms"

# Falco
falco_version         = "3.8.0"
falcosidekick_enabled = true
enable_auto_response  = true
alert_sns_topic_arn   = ""

# GitHub Runners
runner_min_replicas = 1
runner_max_replicas = 50

# Dependency-Track
dependency_track_version = "4.11.0"
db_instance_class        = "db.r6g.large"
sbom_bucket_name         = "ssf-sbom-storage-123456789012"
enable_license_analysis  = true

# Observability
grafana_admin_password_secret    = "grafana-admin-password"
pagerduty_service_key_secret_arn = "arn:aws:secretsmanager:me-central-1:123456789012:secret:pagerduty-key"
enable_security_dashboards       = true

# Signing
kms_key_alias            = "alias/cosign-key"
enable_keyless_signing   = false
github_oidc_provider_arn = ""

# Secrets Management
rotation_days_db        = 30
rotation_days_api       = 90
enable_csi_driver       = true
enable_external_secrets = true

# VPC
enable_vpc_endpoints = true
flow_log_retention   = 2555
