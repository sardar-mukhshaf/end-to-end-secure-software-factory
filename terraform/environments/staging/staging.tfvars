# Staging Environment Overrides
environment = "staging"

security_level = "hardened"

cluster_endpoint_public_access = false

runner_min_replicas = 2
runner_max_replicas = 20

mttp_threshold_days = 7

repositories_list = [
  "payment-service",
  "auth-service",
  "notification-service",
]
