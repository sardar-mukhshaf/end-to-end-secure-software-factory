output "runner_namespace" {
  description = "GitHub runner namespace"
  value       = kubernetes_namespace.runners.metadata[0].name
}

output "runner_irsa_role_arn" {
  description = "Runner IRSA role ARN"
  value       = aws_iam_role.runner_irsa.arn
}
