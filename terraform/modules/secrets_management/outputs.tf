output "secrets_kms_key_arn" {
  description = "KMS key ARN for secrets"
  value       = aws_kms_key.secrets.arn
}

output "db_secret_arn" {
  description = "Database secret ARN"
  value       = aws_secretsmanager_secret.db.arn
}

output "api_secret_arn" {
  description = "API key secret ARN"
  value       = aws_secretsmanager_secret.api.arn
}
