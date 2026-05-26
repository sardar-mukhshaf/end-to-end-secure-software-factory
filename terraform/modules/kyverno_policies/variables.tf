variable "project_name" { type = string }
variable "environment" { type = string }
variable "kyverno_version" { type = string }
variable "enable_policy_reports" { type = bool }
variable "signature_key_type" { type = string }
variable "kms_key_arn" { type = string }
variable "eks_cluster_name" { type = string }
variable "common_tags" { type = map(string) }
