resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project_name}-${var.environment}-db-credentials"
  description             = "Database credentials with automatic rotation"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 30

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-db-credentials"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_secretsmanager_secret_rotation" "db" {
  secret_id           = aws_secretsmanager_secret.db.id
  rotation_lambda_arn = aws_lambda_function.rotation_db.arn

  rotation_rules {
    automatically_after_days = var.rotation_days_db
  }
}

resource "aws_secretsmanager_secret" "api" {
  name                    = "${var.project_name}-${var.environment}-api-keys"
  description             = "API keys with automatic rotation"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 30

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-api-keys"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_secretsmanager_secret_rotation" "api" {
  secret_id           = aws_secretsmanager_secret.api.id
  rotation_lambda_arn = aws_lambda_function.rotation_api.arn

  rotation_rules {
    automatically_after_days = var.rotation_days_api
  }
}

resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-secrets-key"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}-${var.environment}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_lambda_function" "rotation_db" {
  function_name = "${var.project_name}-${var.environment}-rotation-db"
  role          = aws_iam_role.rotation.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60

  filename         = data.archive_file.rotation_db.output_path
  source_code_hash = data.archive_file.rotation_db.output_base64sha256

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-rotation-db"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_lambda_function" "rotation_api" {
  function_name = "${var.project_name}-${var.environment}-rotation-api"
  role          = aws_iam_role.rotation.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60

  filename         = data.archive_file.rotation_api.output_path
  source_code_hash = data.archive_file.rotation_api.output_base64sha256

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-rotation-api"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_iam_role" "rotation" {
  name = "${var.project_name}-${var.environment}-rotation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-rotation-role"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_iam_role_policy" "rotation" {
  name = "${var.project_name}-${var.environment}-rotation-policy"
  role = aws_iam_role.rotation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.secrets.arn
      }
    ]
  })
}

data "archive_file" "rotation_db" {
  type        = "zip"
  source_content = <<-EOF
  import json, boto3, os
  def handler(event, context):
      secret = boto3.client('secretsmanager')
      secret.put_secret_value(SecretId=event['SecretId'], SecretString=json.dumps({"username":"admin","password":os.urandom(24).hex()}))
      return {"statusCode": 200}
  EOF
  source_content_filename = "index.py"
  output_path             = "${path.module}/rotation_db.zip"
}

data "archive_file" "rotation_api" {
  type        = "zip"
  source_content = <<-EOF
  import json, boto3, os
  def handler(event, context):
      secret = boto3.client('secretsmanager')
      secret.put_secret_value(SecretId=event['SecretId'], SecretString=json.dumps({"api_key":os.urandom(32).hex()}))
      return {"statusCode": 200}
  EOF
  source_content_filename = "index.py"
  output_path             = "${path.module}/rotation_api.zip"
}

# Secrets Manager CSI Driver
resource "helm_release" "csi_driver" {
  count = var.enable_csi_driver ? 1 : 0

  name       = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"
  version    = "1.4.0"

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }

  set {
    name  = "enableSecretRotation"
    value = "true"
  }
}

# External Secrets Operator
resource "helm_release" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = "external-secrets"
  version    = "0.9.0"
  create_namespace = true
}
