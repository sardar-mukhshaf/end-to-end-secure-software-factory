output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_cert" {
  description = "EKS cluster CA certificate"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_role_arn" {
  description = "EKS cluster IAM role ARN"
  value       = aws_iam_role.cluster.arn
}

output "oidc_issuer_url" {
  description = "EKS OIDC issuer URL"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "node_role_arn" {
  description = "EKS node IAM role ARN"
  value       = aws_iam_role.node.arn
}

output "irsa_role_arns" {
  description = "Map of IRSA role ARNs"
  value       = { for k, v in aws_iam_role.irsa_template : k => v.arn }
}

output "kms_key_arn" {
  description = "KMS key ARN for EKS"
  value       = aws_kms_key.eks.arn
}
