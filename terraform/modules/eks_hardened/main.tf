locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"
}

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access ? ["0.0.0.0/0"] : []
    security_group_ids      = [aws_security_group.cluster.id]
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policies,
    aws_cloudwatch_log_group.eks,
  ]

  tags = merge(var.common_tags, {
    Name            = local.cluster_name
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_iam_role" "cluster" {
  name = "${local.cluster_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name            = "${local.cluster_name}-role"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController",
  ])

  policy_arn = each.value
  role       = aws_iam_role.cluster.name
}

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 365

  kms_key_id = aws_kms_key.eks.arn

  tags = merge(var.common_tags, {
    Name            = "/aws/eks/${local.cluster_name}/cluster"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS secret encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name            = "${local.cluster_name}-kms"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_security_group" "cluster" {
  name_prefix = "${local.cluster_name}-sg-"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name            = "${local.cluster_name}-sg"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "vpc-cni"
  addon_version = "v1.16.0-eksbuild.1"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.common_tags, {
    Name            = "${local.cluster_name}-vpc-cni"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "coredns"
  addon_version = "v1.11.1-eksbuild.6"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.common_tags, {
    Name            = "${local.cluster_name}-coredns"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "kube-proxy"
  addon_version = "v1.29.0-eksbuild.3"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.common_tags, {
    Name            = "${local.cluster_name}-kube-proxy"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

# OIDC Provider for IRSA
resource "aws_iam_openid_connect_provider" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]

  tags = merge(var.common_tags, {
    Name            = "${local.cluster_name}-oidc"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

# Managed Node Groups
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "system"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  ami_type        = var.node_os == "bottlerocket" ? "BOTTLEROCKET_x86_64" : "AL2_x86_64"
  capacity_type   = "ON_DEMAND"
  disk_size       = 50

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }

  update_config {
    max_unavailable_percentage = 25
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policies,
  ]

  tags = merge(var.common_tags, {
    Name            = "${local.cluster_name}-system-ng"
    Environment     = var.environment
    SecurityProfile = "hardened"
    NodeType        = "system"
  })
}

resource "aws_eks_node_group" "workloads" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "workloads"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  ami_type        = var.node_os == "bottlerocket" ? "BOTTLEROCKET_x86_64" : "AL2_x86_64"
  capacity_type   = "SPOT"
  disk_size       = 50

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 10
  }

  update_config {
    max_unavailable_percentage = 25
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policies,
  ]

  tags = merge(var.common_tags, {
    Name            = "${local.cluster_name}-workloads-ng"
    Environment     = var.environment
    SecurityProfile = "hardened"
    NodeType        = "workloads"
  })
}

resource "aws_iam_role" "node" {
  name = "${local.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name            = "${local.cluster_name}-node-role"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_iam_role_policy_attachment" "node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])

  policy_arn = each.value
  role       = aws_iam_role.node.name
}

# GuardDuty for EKS
resource "aws_guardduty_detector" "this" {
  count = var.enable_guardduty_eks ? 1 : 0

  enable = true

  datasources {
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        enable = true
      }
    }
  }

  tags = merge(var.common_tags, {
    Name            = "${local.cluster_name}-guardduty"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

# Security Hub
resource "aws_securityhub_account" "this" {
  count = var.enable_guardduty_eks ? 1 : 0
}

resource "aws_securityhub_standards_subscription" "cis" {
  count = var.enable_guardduty_eks ? 1 : 0

  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"

  depends_on = [aws_securityhub_account.this]
}

# IRSA Roles — Output references for other modules
resource "aws_iam_role" "irsa_template" {
  for_each = toset(["falco", "kyverno", "external-secrets", "github-runners", "dependency-track"])

  name = "${local.cluster_name}-${each.value}-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${each.value}:${each.value}"
        }
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name            = "${local.cluster_name}-${each.value}-irsa"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}
