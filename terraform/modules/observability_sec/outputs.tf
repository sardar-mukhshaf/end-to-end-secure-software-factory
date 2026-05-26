output "monitoring_namespace" {
  description = "Monitoring namespace"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "grafana_release_name" {
  description = "Grafana Helm release name"
  value       = helm_release.kube_prometheus_stack.name
}
