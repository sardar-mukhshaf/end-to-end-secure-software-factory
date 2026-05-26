# Dev Environment Overrides
environment = "dev"

security_level = "standard"

cluster_endpoint_public_access = true

runner_min_replicas = 1
runner_max_replicas = 5

mttp_threshold_days = 14

repositories_list = [
  "payment-service",
  "auth-service",
]
