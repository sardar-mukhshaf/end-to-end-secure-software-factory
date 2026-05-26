variable "project_name" { type = string }
variable "environment" { type = string }
variable "repositories_list" { type = list(string) }
variable "enable_enhanced_scanning" { type = bool }
variable "replication_region" { type = string }
variable "kms_key_arn" { type = string }
variable "eks_cluster_role_arns" { type = list(string) }
variable "common_tags" { type = map(string) }
