variable "project_name" { type = string }
variable "environment" { type = string }
variable "falco_version" { type = string }
variable "falcosidekick_enabled" { type = bool }
variable "alert_sns_topic_arn" { type = string }
variable "enable_auto_response" { type = bool }
variable "eks_cluster_name" { type = string }
variable "common_tags" { type = map(string) }
variable "aws_region" { type = string }

