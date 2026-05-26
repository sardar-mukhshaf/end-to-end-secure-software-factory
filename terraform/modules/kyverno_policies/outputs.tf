output "kyverno_namespace" {
  description = "Kyverno namespace"
  value       = kubernetes_namespace.kyverno.metadata[0].name
}

output "kyverno_release_name" {
  description = "Helm release name for Kyverno"
  value       = helm_release.kyverno.name
}
