variable "project_name" { type = string }
variable "environment" { type = string }
variable "vpc_cidr" { type = string }
variable "az_count" { type = number }
variable "enable_vpc_endpoints" { type = bool }
variable "flow_log_retention" { type = number }
variable "common_tags" { type = map(string) }
