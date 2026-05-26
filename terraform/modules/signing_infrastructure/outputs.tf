output "kms_key_arn" {
  description = "KMS key ARN for Cosign signing"
  value       = aws_kms_key.cosign.arn
  sensitive   = true
}

output "kms_key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.cosign.key_id
}

output "github_oidc_role_arn" {
  description = "GitHub OIDC role ARN"
  value       = var.enable_keyless_signing ? aws_iam_role.github_oidc[0].arn : ""
}
