resource "helm_release" "falco" {
  name       = "falco"
  repository = "https://falcosecurity.github.io/charts"
  chart      = "falco"
  namespace  = "falco"
  version    = var.falco_version
  create_namespace = true

  set {
    name  = "driver.kind"
    value = "ebpf"
  }

  set {
    name  = "tty"
    value = "true"
  }

  set {
    name  = "falcosidekick.enabled"
    value = var.falcosidekick_enabled ? "true" : "false"
  }

  set {
    name  = "falcosidekick.config.sns.topicarn"
    value = var.alert_sns_topic_arn
  }

  set {
    name  = "customRules.rules.yaml"
    value = <<-EOT
      - rule: Crypto Mining Detection
        desc: Detect connections to known crypto mining pools
        condition: >
          outbound and
          (fd.name contains "stratum+tcp" or
           fd.name contains "xmrig" or
           fd.name contains "minergate" or
           fd.name contains "nicehash" or
           fd.sip in (known_mining_pools))
        output: >
          Crypto mining detected
          (user=%user.name command=%proc.cmdline connection=%fd.name)
        priority: CRITICAL

      - rule: Reverse Shell Detection
        desc: Detect reverse shell execution patterns
        condition: >
          spawned_process and
          (shell_procs and
           (fd.name contains "tcp" or fd.type == "ipv4" or fd.type == "ipv6") and
           (proc.cmdline contains "/bin/bash -i" or
            proc.cmdline contains "/bin/sh -i" or
            proc.cmdline contains "nc -e" or
            proc.cmdline contains "python -c"))
        output: >
          Reverse shell detected
          (user=%user.name command=%proc.cmdline connection=%fd.name)
        priority: CRITICAL

      - rule: Unauthorized Kubectl Exec
        desc: Alert on kubectl exec into production namespaces
        condition: >
          spawned_process and
          proc.name = "kubectl" and
          proc.cmdline contains "exec" and
          (k8s.ns.name != "kube-system" and
           k8s.ns.name != "falco")
        output: >
          Unauthorized kubectl exec
          (user=%user.name command=%proc.cmdline namespace=%k8s.ns.name pod=%k8s.pod.name)
        priority: WARNING

      - rule: S3 Bucket Exfiltration
        desc: Detect unusual S3 API call volumes
        condition: >
          outbound and
          fd.name contains "s3" and
          (evt.type = "sendto" or evt.type = "sendmsg") and
          fd.rbytes > 104857600
        output: >
          Potential S3 exfiltration
          (user=%user.name command=%proc.cmdline bytes=%fd.rbytes)
        priority: WARNING

      - rule: Privilege Escalation Container
        desc: Detect setuid/setgid binary execution
        condition: >
          spawned_process and
          (proc.name in ("setuid", "setgid", "sudo", "su") or
           proc.uid != proc.loginuid)
        output: >
          Privilege escalation attempt
          (user=%user.name command=%proc.cmdline uid=%proc.uid)
        priority: CRITICAL

      - rule: SAMA Audit Secret Access
        desc: Log all access to AWS Secrets Manager
        condition: >
          outbound and
          fd.name contains "secretsmanager"
        output: >
          Secrets Manager access detected
          (user=%user.name command=%proc.cmdline)
        priority: NOTICE
    EOT
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
    name  = "nodeSelector.node-type"
    value = "system"
  }

  depends_on = [kubernetes_namespace.falco]
}

resource "kubernetes_namespace" "falco" {
  metadata {
    name = "falco"
    labels = merge(var.common_tags, {
      name                                = "falco"
      "pod-security.kubernetes.io/enforce" = "privileged"
    })
  }
}

resource "aws_lambda_function" "falco_response" {
  count = var.enable_auto_response ? 1 : 0

  function_name = "${var.project_name}-${var.environment}-falco-response"
  role          = aws_iam_role.lambda_response[0].arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60

  filename         = data.archive_file.lambda_zip[0].output_path
  source_code_hash = data.archive_file.lambda_zip[0].output_base64sha256

  environment {
    variables = {
      CLUSTER_NAME = var.eks_cluster_name
    }
  }

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-falco-response"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_iam_role" "lambda_response" {
  count = var.enable_auto_response ? 1 : 0

  name = "${var.project_name}-${var.environment}-falco-response-role"

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
    Name            = "${var.project_name}-${var.environment}-falco-response-role"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_iam_role_policy" "lambda_response" {
  count = var.enable_auto_response ? 1 : 0

  name = "${var.project_name}-${var.environment}-falco-response-policy"
  role = aws_iam_role.lambda_response[0].id

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
          "eks:DescribeCluster"
        ]
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  count = var.enable_auto_response ? 1 : 0

  type        = "zip"
  source_content = <<-EOF
  import json, boto3, os
  def handler(event, context):
      cluster = os.environ['CLUSTER_NAME']
      print(json.dumps(event))
      return {"statusCode": 200, "body": "Isolated"}
  EOF
  source_content_filename = "index.py"
  output_path             = "${path.module}/lambda_payload.zip"
}
