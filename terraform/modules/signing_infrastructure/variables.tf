variable "project_name" { type = string }
variable "environment" { type = string }
variable "kms_key_alias" { type = string }
variable "enable_keyless_signing" { type = bool }
variable "github_oidc_provider_arn" { type = string }
variable "github_org" { type = string }
variable "common_tags" { type = map(string) }
