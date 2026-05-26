locals {
  dtrack_name = "${var.project_name}-${var.environment}-dtrack"
}

resource "aws_db_subnet_group" "dtrack" {
  name       = "${local.dtrack_name}-db-subnet"
  subnet_ids = var.subnet_ids

  tags = merge(var.common_tags, {
    Name            = "${local.dtrack_name}-db-subnet"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_db_instance" "dtrack" {
  identifier              = local.dtrack_name
  engine                  = "postgres"
  engine_version          = "15.4"
  instance_class          = var.db_instance_class
  allocated_storage       = 100
  max_allocated_storage   = 500
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.dtrack.arn
  db_name                 = "dependencytrack"
  username                = "dtrack_admin"
  password                = random_password.dtrack.result
  db_subnet_group_name    = aws_db_subnet_group.dtrack.name
  multi_az                = true
  publicly_accessible     = false
  vpc_security_group_ids  = [aws_security_group.dtrack_db.id]
  backup_retention_period = 30
  deletion_protection     = true

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.common_tags, {
    Name            = local.dtrack_name
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "random_password" "dtrack" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "dtrack_db" {
  name                    = "${local.dtrack_name}-db-password"
  description             = "Dependency-Track database password"
  kms_key_id              = aws_kms_key.dtrack.arn
  recovery_window_in_days = 30

  tags = merge(var.common_tags, {
    Name            = "${local.dtrack_name}-db-password"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_secretsmanager_secret_version" "dtrack_db" {
  secret_id     = aws_secretsmanager_secret.dtrack_db.id
  secret_string = random_password.dtrack.result
}

resource "aws_kms_key" "dtrack" {
  description             = "KMS key for Dependency-Track"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name            = "${local.dtrack_name}-kms"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_security_group" "dtrack_db" {
  name_prefix = "${local.dtrack_name}-db-sg-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "PostgreSQL from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
    self        = true
  }

  tags = merge(var.common_tags, {
    Name            = "${local.dtrack_name}-db-sg"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_s3_bucket" "sbom" {
  bucket = var.sbom_bucket_name

  tags = merge(var.common_tags, {
    Name            = var.sbom_bucket_name
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_s3_bucket_versioning" "sbom" {
  bucket = aws_s3_bucket.sbom.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sbom" {
  bucket = aws_s3_bucket.sbom.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.dtrack.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "sbom" {
  bucket = aws_s3_bucket.sbom.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "dtrack_irsa" {
  name = "${local.dtrack_name}-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(var.eks_oidc_issuer_url, "https://", "")}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.eks_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:dependency-track:dependency-track"
          "${replace(var.eks_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name            = "${local.dtrack_name}-irsa"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_iam_role_policy" "dtrack_s3" {
  name = "${local.dtrack_name}-s3-policy"
  role = aws_iam_role.dtrack_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.sbom.arn,
          "${aws_s3_bucket.sbom.arn}/*"
        ]
      },
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.dtrack_db.arn
      }
    ]
  })
}

data "aws_caller_identity" "current" {}
