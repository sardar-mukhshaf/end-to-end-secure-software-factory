terraform {
  required_version = "~> 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.common_tags, {
      Environment     = var.environment
      SecurityProfile = var.security_level
      ManagedBy       = "terraform"
    })
  }
}

provider "kubernetes" {
  host                   = module.eks_hardened.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_hardened.cluster_ca_cert)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks_hardened.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_hardened.cluster_ca_cert)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "github" {
  token = data.aws_secretsmanager_secret_version.github_token.secret_string
  owner = var.github_org
}
