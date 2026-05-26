# Production Environment Overrides
environment = "prod"

security_level = "maximum"

cluster_endpoint_public_access = false

runner_min_replicas = 3
runner_max_replicas = 50

mttp_threshold_days = 3

repositories_list = [
  "payment-service",
  "auth-service",
  "notification-service",
  "reporting-service",
]
