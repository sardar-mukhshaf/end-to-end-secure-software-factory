locals {
  runner_labels = ["secure-runner", "${var.project_name}-${var.environment}"]
}

resource "kubernetes_namespace" "runners" {
  metadata {
    name = var.runner_namespace
    labels = merge(var.common_tags, {
      name            = var.runner_namespace
      security        = "high"
      pod-security.kubernetes.io/enforce = "restricted"
    })
  }
}

resource "kubernetes_service_account" "runner" {
  metadata {
    name      = "github-runner"
    namespace = kubernetes_namespace.runners.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.runner_irsa.arn
    }
  }
}

resource "aws_iam_role" "runner_irsa" {
  name = "${var.project_name}-${var.environment}-runner-irsa"

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
          "${replace(var.eks_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${var.runner_namespace}:github-runner"
          "${replace(var.eks_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-runner-irsa"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_iam_role_policy" "runner_policy" {
  name = "${var.project_name}-${var.environment}-runner-policy"
  role = aws_iam_role.runner_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.github_app_id_secret_arn
      },
      {
        Sid    = "S3ReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-*/*"
      }
    ]
  })
}

resource "helm_release" "arc" {
  name       = "arc"
  repository = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart      = "actions-runner-controller"
  namespace  = kubernetes_namespace.runners.metadata[0].name
  version    = "0.23.7"

  set {
    name  = "authSecret.create"
    value = "true"
  }

  set {
    name  = "authSecret.github_app_id"
    value = "${data.aws_secretsmanager_secret_version.github_app_id.secret_string}"
  }

  set {
    name  = "runnerReplicas.min"
    value = var.runner_min_replicas
  }

  set {
    name  = "runnerReplicas.max"
    value = var.runner_max_replicas
  }

  depends_on = [kubernetes_namespace.runners]
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "runner" {
  metadata {
    name      = "runner-hpa"
    namespace = kubernetes_namespace.runners.metadata[0].name
  }
  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "arc-actions-runner-controller"
    }
    min_replicas = var.runner_min_replicas
    max_replicas = var.runner_max_replicas
    metric {
      type = "External"
      external {
        metric {
          name = "github_runner_queue_length"
        }
        target {
          type          = "AverageValue"
          average_value = "1"
        }
      }
    }
  }
}

resource "kubernetes_pod_disruption_budget_v1" "runner" {
  metadata {
    name      = "runner-pdb"
    namespace = kubernetes_namespace.runners.metadata[0].name
  }
  spec {
    min_available = 1
    selector {
      match_labels = {
        app = "actions-runner-controller"
      }
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_secretsmanager_secret_version" "github_app_id" {
  secret_id = var.github_app_id_secret_arn
}
