resource "helm_release" "kyverno" {
  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno"
  chart      = "kyverno"
  namespace  = "kyverno"
  version    = var.kyverno_version
  create_namespace = true

  set {
    name  = "replicaCount"
    value = "3"
  }

  set {
    name  = "resources.limits.cpu"
    value = "1000m"
  }

  set {
    name  = "resources.limits.memory"
    value = "1Gi"
  }

  set {
    name  = "config.webhooks"
    value = jsonencode([{
      namespaceSelector = {
        matchExpressions = [{
          key      = "kubernetes.io/metadata.name"
          operator = "NotIn"
          values   = ["kyverno"]
        }]
      }
    }])
  }

  depends_on = [kubernetes_namespace.kyverno]
}

resource "kubernetes_namespace" "kyverno" {
  metadata {
    name = "kyverno"
    labels = merge(var.common_tags, {
      name                                = "kyverno"
      "pod-security.kubernetes.io/enforce" = "privileged"
    })
  }
}

resource "kubernetes_manifest" "verify_image_signatures" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "verify-image-signatures"
      annotations = {
        "policies.kyverno.io/title"       = "Verify Image Signatures"
        "policies.kyverno.io/severity"    = "critical"
        "policies.kyverno.io/category"    = "Supply Chain Security"
      }
    }
    spec = {
      validationFailureAction = var.environment == "prod" ? "Enforce" : "Audit"
      background              = true
      rules = [{
        name = "verify-cosign-signature"
        match = {
          resources = {
            kinds = ["Pod"]
          }
        }
        exclude = {
          resources = {
            namespaces = ["kube-system", "kyverno", "falco", "github-runners"]
          }
        }
        verifyImages = [{
          imageReferences = ["*.dkr.ecr.*.amazonaws.com/*"]
          attestors = [{
            entries = [{
              keys = {
                publicKeys = var.signature_key_type == "kms" ? "kms://${var.kms_key_arn}" : ""
                kms        = var.signature_key_type == "kms" ? var.kms_key_arn : ""
                signatureAlgorithm = "sha256"
              }
            }]
          }]
        }]
      }]
    }
  }

  depends_on = [helm_release.kyverno]
}

resource "kubernetes_manifest" "restrict_image_registries" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "restrict-image-registries"
      annotations = {
        "policies.kyverno.io/title"    = "Restrict Image Registries"
        "policies.kyverno.io/severity" = "critical"
        "policies.kyverno.io/category" = "Supply Chain Security"
      }
    }
    spec = {
      validationFailureAction = var.environment == "prod" ? "Enforce" : "Audit"
      background              = true
      rules = [{
        name = "validate-registries"
        match = {
          resources = {
            kinds = ["Pod"]
          }
        }
        exclude = {
          resources = {
            namespaces = ["kube-system", "kyverno", "falco", "github-runners"]
          }
        }
        validate = {
          message = "Only private ECR registries are allowed."
          pattern = {
            spec = {
              containers = [{
                image = "*.dkr.ecr.*.amazonaws.com/*"
              }]
            }
          }
        }
      }]
    }
  }

  depends_on = [helm_release.kyverno]
}

resource "kubernetes_manifest" "require_resource_limits" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "require-resource-limits"
      annotations = {
        "policies.kyverno.io/title"    = "Require Resource Limits"
        "policies.kyverno.io/severity" = "medium"
        "policies.kyverno.io/category" = "Best Practices"
      }
    }
    spec = {
      validationFailureAction = var.environment == "prod" ? "Enforce" : "Audit"
      background              = true
      rules = [{
        name = "validate-limits"
        match = {
          resources = {
            kinds = ["Pod"]
          }
        }
        exclude = {
          resources = {
            namespaces = ["kube-system", "kyverno", "falco", "github-runners"]
          }
        }
        validate = {
          message = "CPU and memory limits are required."
          pattern = {
            spec = {
              containers = [{
                resources = {
                  limits = {
                    cpu    = "?*"
                    memory = "?*"
                  }
                }
              }]
            }
          }
        }
      }]
    }
  }

  depends_on = [helm_release.kyverno]
}

resource "kubernetes_manifest" "require_non_root" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "require-non-root"
      annotations = {
        "policies.kyverno.io/title"    = "Require Non-Root"
        "policies.kyverno.io/severity" = "high"
        "policies.kyverno.io/category" = "Pod Security"
      }
    }
    spec = {
      validationFailureAction = var.environment == "prod" ? "Enforce" : "Audit"
      background              = true
      rules = [{
        name = "check-security-context"
        match = {
          resources = {
            kinds = ["Pod"]
          }
        }
        exclude = {
          resources = {
            namespaces = ["kube-system", "kyverno", "falco", "github-runners"]
          }
        }
        validate = {
          message = "Pod must run as non-root with read-only root filesystem and drop ALL capabilities."
          pattern = {
            spec = {
              securityContext = {
                runAsNonRoot = true
              }
              containers = [{
                securityContext = {
                  allowPrivilegeEscalation = false
                  readOnlyRootFilesystem   = true
                  capabilities = {
                    drop = ["ALL"]
                  }
                }
              }]
            }
          }
        }
      }]
    }
  }

  depends_on = [helm_release.kyverno]
}

resource "kubernetes_manifest" "disallow_host_path" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "disallow-host-path"
      annotations = {
        "policies.kyverno.io/title"    = "Disallow hostPath Volumes"
        "policies.kyverno.io/severity" = "high"
        "policies.kyverno.io/category" = "Pod Security"
      }
    }
    spec = {
      validationFailureAction = var.environment == "prod" ? "Enforce" : "Audit"
      background              = true
      rules = [{
        name = "check-host-path"
        match = {
          resources = {
            kinds = ["Pod"]
          }
        }
        exclude = {
          resources = {
            namespaces = ["kube-system", "kyverno", "falco", "github-runners"]
          }
        }
        validate = {
          message = "hostPath volumes are forbidden."
          pattern = {
            spec = {
              volumes = [{
                X(hostPath) = "?*"
              }]
            }
          }
        }
      }]
    }
  }

  depends_on = [helm_release.kyverno]
}

resource "kubernetes_manifest" "disallow_privilege_escalation" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "disallow-privilege-escalation"
      annotations = {
        "policies.kyverno.io/title"    = "Disallow Privilege Escalation"
        "policies.kyverno.io/severity" = "high"
        "policies.kyverno.io/category" = "Pod Security"
      }
    }
    spec = {
      validationFailureAction = var.environment == "prod" ? "Enforce" : "Audit"
      background              = true
      rules = [{
        name = "check-priv-esc"
        match = {
          resources = {
            kinds = ["Pod"]
          }
        }
        exclude = {
          resources = {
            namespaces = ["kube-system", "kyverno", "falco", "github-runners"]
          }
        }
        validate = {
          message = "allowPrivilegeEscalation must be false."
          pattern = {
            spec = {
              containers = [{
                securityContext = {
                  allowPrivilegeEscalation = false
                }
              }]
            }
          }
        }
      }]
    }
  }

  depends_on = [helm_release.kyverno]
}

resource "kubernetes_manifest" "restrict_external_ips" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "restrict-external-ips"
      annotations = {
        "policies.kyverno.io/title"    = "Restrict External IPs"
        "policies.kyverno.io/severity" = "medium"
        "policies.kyverno.io/category" = "Network Security"
      }
    }
    spec = {
      validationFailureAction = var.environment == "prod" ? "Enforce" : "Audit"
      background              = true
      rules = [{
        name = "check-external-ips"
        match = {
          resources = {
            kinds = ["Service"]
          }
        }
        validate = {
          message = "externalIPs are not allowed."
          pattern = {
            spec = {
              X(externalIPs) = "?*"
            }
          }
        }
      }]
    }
  }

  depends_on = [helm_release.kyverno]
}

resource "kubernetes_manifest" "enforce_pod_security_standards" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "enforce-pod-security-standards"
      annotations = {
        "policies.kyverno.io/title"    = "Enforce Pod Security Standards"
        "policies.kyverno.io/severity" = "critical"
        "policies.kyverno.io/category" = "Pod Security"
      }
    }
    spec = {
      validationFailureAction = var.environment == "prod" ? "Enforce" : "Audit"
      background              = true
      rules = [{
        name = "restricted-profile"
        match = {
          resources = {
            kinds = ["Pod"]
          }
        }
        exclude = {
          resources = {
            namespaces = ["kube-system", "kyverno", "falco", "github-runners"]
          }
        }
        validate = {
          message = "Pod must comply with restricted Pod Security Standards."
          podSecurity = {
            level   = "restricted"
            version = "latest"
          }
        }
      }]
    }
  }

  depends_on = [helm_release.kyverno]
}
