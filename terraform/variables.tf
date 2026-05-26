# ---------------------------------------------------------------------------
# Global Variables — Driven Exclusively from terraform.tfvars
# ---------------------------------------------------------------------------

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "ssf"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric with hyphens only."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "me-central-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region format."
  }
}

variable "dr_region" {
  description = "Disaster recovery / replication region"
  type        = string
  default     = "me-south-1"
}

variable "security_level" {
  description = "Security hardening level"
  type        = string
  default     = "hardened"

  validation {
    condition     = contains(["standard", "hardened", "maximum"], var.security_level)
    error_message = "security_level must be one of: standard, hardened, maximum."
  }
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "secure-software-factory"
    CostCenter  = "security"
    Compliance  = "SAMA-CSF"
  }
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_token_secret_arn" {
  description = "Secrets Manager ARN for GitHub token"
  type        = string
}

variable "mttp_threshold_days" {
  description = "Mean Time To Patch threshold in days"
  type        = number
  default     = 7

  validation {
    condition     = var.mttp_threshold_days > 0 && var.mttp_threshold_days < 30
    error_message = "mttp_threshold_days must be between 1 and 29."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "az_count" {
  description = "Number of availability zones"
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "repositories_list" {
  description = "List of microservice names for ECR repositories"
  type        = list(string)
  default     = []
}

variable "enable_enhanced_scanning" {
  description = "Enable ECR enhanced image scanning"
  type        = bool
  default     = true
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "node_os" {
  description = "EKS node OS: bottlerocket or al2"
  type        = string
  default     = "bottlerocket"

  validation {
    condition     = contains(["bottlerocket", "al2"], var.node_os)
    error_message = "node_os must be bottlerocket or al2."
  }
}

variable "enable_guardduty_eks" {
  description = "Enable GuardDuty for EKS protection"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Allow public access to EKS endpoint"
  type        = bool
  default     = false
}

variable "kyverno_version" {
  description = "Kyverno Helm chart version"
  type        = string
  default     = "3.2.0"
}

variable "falco_version" {
  description = "Falco Helm chart version"
  type        = string
  default     = "3.8.0"
}

variable "dependency_track_version" {
  description = "Dependency-Track container version"
  type        = string
  default     = "4.11.0"
}

variable "runner_min_replicas" {
  description = "Minimum GitHub runner replicas"
  type        = number
  default     = 1
}

variable "runner_max_replicas" {
  description = "Maximum GitHub runner replicas"
  type        = number
  default     = 50
}

variable "db_instance_class" {
  description = "RDS instance class for Dependency-Track"
  type        = string
  default     = "db.r6g.large"
}

variable "sbom_bucket_name" {
  description = "S3 bucket name for SBOM storage"
  type        = string
}

variable "pagerduty_service_key_secret_arn" {
  description = "Secrets Manager ARN for PagerDuty service key"
  type        = string
}

variable "grafana_admin_password_secret" {
  description = "Secrets Manager name for Grafana admin password"
  type        = string
}

variable "rotation_days_db" {
  description = "Database credential rotation period in days"
  type        = number
  default     = 30
}

variable "rotation_days_api" {
  description = "API key rotation period in days"
  type        = number
  default     = 90
}

variable "enable_csi_driver" {
  description = "Enable Secrets Manager CSI driver"
  type        = bool
  default     = true
}

variable "enable_external_secrets" {
  description = "Enable External Secrets Operator"
  type        = bool
  default     = true
}

variable "enable_policy_reports" {
  description = "Enable Kyverno policy reports"
  type        = bool
  default     = true
}

variable "signature_key_type" {
  description = "Cosign signature key type: kms or keyless"
  type        = string
  default     = "kms"

  validation {
    condition     = contains(["kms", "keyless"], var.signature_key_type)
    error_message = "signature_key_type must be kms or keyless."
  }
}

variable "enable_keyless_signing" {
  description = "Enable Cosign keyless signing with OIDC"
  type        = bool
  default     = false
}

variable "kms_key_alias" {
  description = "KMS key alias for Cosign signing"
  type        = string
  default     = "alias/cosign-key"
}

variable "github_oidc_provider_arn" {
  description = "IAM OIDC provider ARN for GitHub Actions"
  type        = string
  default     = ""
}

variable "enable_auto_response" {
  description = "Enable automatic Falco response actions"
  type        = bool
  default     = true
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services"
  type        = bool
  default     = true
}

variable "flow_log_retention" {
  description = "VPC flow log retention in days (SAMA: 7 years = 2555 days)"
  type        = number
  default     = 2555
}

variable "falcosidekick_enabled" {
  description = "Enable Falcosidekick for alert routing"
  type        = bool
  default     = true
}

variable "alert_sns_topic_arn" {
  description = "SNS topic ARN for security alerts"
  type        = string
  default     = ""
}

variable "enable_security_dashboards" {
  description = "Enable Grafana security dashboards"
  type        = bool
  default     = true
}

variable "enable_license_analysis" {
  description = "Enable license analysis in Dependency-Track"
  type        = bool
  default     = true
}
