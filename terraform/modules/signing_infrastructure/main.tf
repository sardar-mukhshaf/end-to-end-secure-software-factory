resource "aws_kms_key" "cosign" {
  description              = "KMS key for Cosign image signing"
  deletion_window_in_days  = 30
  enable_key_rotation      = true
  multi_region             = false
  customer_master_key_spec = "RSA_4096"
  key_usage                = "SIGN_VERIFY"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowGitHubRunnersSign"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "kms:Sign",
          "kms:GetPublicKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/Environment" = var.environment
          }
        }
      }
    ]
  })

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-cosign-key"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_kms_alias" "cosign" {
  name          = var.kms_key_alias
  target_key_id = aws_kms_key.cosign.key_id
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.enable_keyless_signing ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4e98bab03faadb97b34396831e3780aea1"]

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-github-oidc"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_iam_role" "github_oidc" {
  count = var.enable_keyless_signing ? 1 : 0

  name = "${var.project_name}-${var.environment}-github-oidc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github[0].arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/*"
        }
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-github-oidc-role"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_iam_role_policy" "github_oidc_kms" {
  count = var.enable_keyless_signing ? 1 : 0

  name = "${var.project_name}-${var.environment}-github-oidc-kms"
  role = aws_iam_role.github_oidc[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSCosign"
        Effect = "Allow"
        Action = [
          "kms:Sign",
          "kms:GetPublicKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.cosign.arn
      }
    ]
  })
}

data "aws_caller_identity" "current" {}
