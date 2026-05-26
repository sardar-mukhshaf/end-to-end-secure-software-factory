output "falco_namespace" {
  description = "Falco namespace"
  value       = kubernetes_namespace.falco.metadata[0].name
}

output "falco_release_name" {
  description = "Helm release name for Falco"
  value       = helm_release.falco.name
}
