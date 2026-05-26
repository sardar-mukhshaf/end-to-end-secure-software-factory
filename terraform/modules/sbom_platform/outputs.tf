output "dependency_track_db_endpoint" {
  description = "Dependency-Track database endpoint"
  value       = aws_db_instance.dtrack.endpoint
  sensitive   = true
}

output "sbom_bucket_arn" {
  description = "SBOM S3 bucket ARN"
  value       = aws_s3_bucket.sbom.arn
}

output "dtrack_irsa_role_arn" {
  description = "Dependency-Track IRSA role ARN"
  value       = aws_iam_role.dtrack_irsa.arn
}
