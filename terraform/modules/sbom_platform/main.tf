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
    cidr_blocks = [var.vpc_cidr]
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

# ---------------------------------------------------------------------------
# Dependency-Track: Kubernetes Resources (deployed dynamically via Terraform)
# ---------------------------------------------------------------------------

resource "kubernetes_namespace" "dtrack" {
  metadata {
    name = "dependency-track"
    labels = merge(var.common_tags, {
      name                                = "dependency-track"
      "pod-security.kubernetes.io/enforce" = "restricted"
    })
  }
}

resource "kubernetes_config_map_v1" "dtrack" {
  metadata {
    name      = "dependency-track-config"
    namespace = kubernetes_namespace.dtrack.metadata[0].name
  }

  data = {
    ALPINE_APPLICATION_URL           = "https://dependency-track.${var.domain_name}"
    ALPINE_OIDC_ENABLED              = "false"
    ALPINE_METRICS_ENABLED           = "true"
    ALPINE_METRICS_AUTH_USERNAME     = "prometheus"
    ALPINE_DATABASE_MODE             = "external"
    ALPINE_DATABASE_DRIVER           = "org.postgresql.Driver"
    ALPINE_DATABASE_DRIVER_PATH      = "/extlib/postgresql.jar"
    ALPINE_DATABASE_URL              = "jdbc:postgresql://${aws_db_instance.dtrack.endpoint}/${aws_db_instance.dtrack.db_name}"
  }
}

resource "kubernetes_secret_v1" "dtrack_db" {
  metadata {
    name      = "dependency-track-db"
    namespace = kubernetes_namespace.dtrack.metadata[0].name
  }

  data = {
    password = random_password.dtrack.result
    url      = "jdbc:postgresql://${aws_db_instance.dtrack.endpoint}/${aws_db_instance.dtrack.db_name}"
  }

  type = "Opaque"
}

resource "kubernetes_service_account_v1" "dtrack" {
  metadata {
    name      = "dependency-track"
    namespace = kubernetes_namespace.dtrack.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.dtrack_irsa.arn
    }
  }
}

resource "kubernetes_deployment_v1" "dtrack_apiserver" {
  metadata {
    name      = "dependency-track-apiserver"
    namespace = kubernetes_namespace.dtrack.metadata[0].name
    labels = {
      app       = "dependency-track"
      component = "apiserver"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app       = "dependency-track"
        component = "apiserver"
      }
    }
    template {
      metadata {
        labels = {
          app       = "dependency-track"
          component = "apiserver"
        }
      }
      spec {
        service_account_name = kubernetes_service_account_v1.dtrack.metadata[0].name
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
        }

        container {
          name  = "apiserver"
          image = "dependencytrack/apiserver:${var.dependency_track_version}"

          port { container_port = 8080 }

          env_from {
            config_map_ref { name = kubernetes_config_map_v1.dtrack.metadata[0].name }
          }

          env {
            name = "ALPINE_DATABASE_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.dtrack_db.metadata[0].name
                key  = "password"
              }
            }
          }

          resources {
            limits   = { cpu = "4000m", memory = "8Gi" }
            requests = { cpu = "1000m", memory = "4Gi" }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            capabilities { drop = ["ALL"] }
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
        }

        volume {
          name      = "data"
          empty_dir {}
        }
      }
    }
  }

  depends_on = [aws_db_instance.dtrack]
}

resource "kubernetes_deployment_v1" "dtrack_frontend" {
  metadata {
    name      = "dependency-track-frontend"
    namespace = kubernetes_namespace.dtrack.metadata[0].name
    labels = {
      app       = "dependency-track"
      component = "frontend"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app       = "dependency-track"
        component = "frontend"
      }
    }
    template {
      metadata {
        labels = {
          app       = "dependency-track"
          component = "frontend"
        }
      }
      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
        }

        container {
          name  = "frontend"
          image = "dependencytrack/frontend:${var.dependency_track_version}"

          port { container_port = 8080 }

          env {
            name  = "API_BASE_URL"
            value = "http://dependency-track-apiserver:8080"
          }

          resources {
            limits   = { cpu = "1000m", memory = "2Gi" }
            requests = { cpu = "250m", memory = "512Mi" }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            capabilities { drop = ["ALL"] }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "dtrack_apiserver" {
  metadata {
    name      = "dependency-track-apiserver"
    namespace = kubernetes_namespace.dtrack.metadata[0].name
  }
  spec {
    selector = { app = "dependency-track", component = "apiserver" }
    port {
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_service_v1" "dtrack_frontend" {
  metadata {
    name      = "dependency-track-frontend"
    namespace = kubernetes_namespace.dtrack.metadata[0].name
  }
  spec {
    selector = { app = "dependency-track", component = "frontend" }
    port {
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "dtrack" {
  metadata {
    name      = "dependency-track"
    namespace = kubernetes_namespace.dtrack.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme"             = "internal"
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/listen-ports"       = "[{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/certificate-arn"    = var.acm_certificate_arn
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = "dependency-track.${var.domain_name}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.dtrack_frontend.metadata[0].name
              port { number = 8080 }
            }
          }
        }
        path {
          path      = "/api"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.dtrack_apiserver.metadata[0].name
              port { number = 8080 }
            }
          }
        }
      }
    }
  }
}

