resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = "56.0.0"
  create_namespace = true

  set {
    name  = "grafana.enabled"
    value = "true"
  }

  set {
    name  = "grafana.admin.existingSecret"
    value = var.grafana_admin_password_secret
  }

  set {
    name  = "grafana.dashboardProviders.dashboardproviders.yaml.apiVersion"
    value = "1"
  }

  set {
    name  = "grafana.dashboardsConfigMaps.default"
    value = "grafana-dashboards"
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "30d"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "100Gi"
  }

  values = [
    <<-EOT
    grafana:
      additionalDataSources:
        - name: Dependency-Track
          type: simpod-json-datasource
          url: http://dependency-track-apiserver:8080
          access: proxy
          isDefault: false
    EOT
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = merge(var.common_tags, {
      name                                = "monitoring"
      "pod-security.kubernetes.io/enforce" = "restricted"
    })
  }
}

resource "kubernetes_config_map_v1" "grafana_dashboards" {
  count = var.enable_security_dashboards ? 1 : 0

  metadata {
    name      = "grafana-dashboards"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "mttp-cve-dashboard.json"          = file("${path.module}/dashboards/mttp-cve-dashboard.json")
    "supply-chain-security.json"       = file("${path.module}/dashboards/supply-chain-security.json")
    "runtime-threat-detection.json"    = file("${path.module}/dashboards/runtime-threat-detection.json")
    "pipeline-security-gates.json"     = file("${path.module}/dashboards/pipeline-security-gates.json")
  }
}

resource "aws_cloudwatch_log_group" "pipeline" {
  name              = "/${var.project_name}/${var.environment}/pipeline"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.cloudwatch.arn

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-pipeline-logs"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_kms_key" "cloudwatch" {
  description             = "KMS key for CloudWatch log encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-cloudwatch-key"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}
