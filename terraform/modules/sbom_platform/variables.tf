variable "project_name" { type = string }
variable "environment" { type = string }
variable "dependency_track_version" { type = string }
variable "db_instance_class" { type = string }
variable "sbom_bucket_name" { type = string }
variable "enable_license_analysis" { type = bool }
variable "subnet_ids" { type = list(string) }
variable "vpc_id" { type = string }
variable "eks_cluster_name" { type = string }
variable "eks_oidc_issuer_url" { type = string }
variable "common_tags" { type = map(string) }
variable "domain_name" { type = string }
variable "acm_certificate_arn" { type = string }
variable "vpc_cidr" { type = string }

