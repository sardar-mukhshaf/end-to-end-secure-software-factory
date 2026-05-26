locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-vpc"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-private-${count.index + 1}"
    Environment     = var.environment
    Type            = "private"
    SecurityProfile = "hardened"
  })
}

resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Environment     = var.environment
    Type            = "public"
    SecurityProfile = "hardened"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-igw"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_eip" "nat" {
  count  = var.az_count
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_nat_gateway" "this" {
  count = var.az_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-private-rt-${count.index + 1}"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_route_table_association" "private" {
  count = var.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-public-rt"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_flow_log" "this" {
  vpc_id                   = aws_vpc.this.id
  traffic_type             = "ALL"
  log_destination_type     = "s3"
  log_destination          = aws_s3_bucket.flow_logs.arn
  max_aggregation_interval = 600

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-flow-log"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_s3_bucket" "flow_logs" {
  bucket = "${var.project_name}-${var.environment}-flow-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-flow-logs"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_s3_bucket_versioning" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.flow_logs.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_kms_key" "flow_logs" {
  description             = "KMS key for VPC flow logs encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-flow-logs-key"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_kms_alias" "flow_logs" {
  name          = "alias/${var.project_name}-${var.environment}-flow-logs"
  target_key_id = aws_kms_key.flow_logs.key_id
}

resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-alb-sg"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.project_name}-${var.environment}-eks-node-"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow inter-node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-eks-node-sg"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

# VPC Endpoints
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  route_table_ids = aws_route_table.private[*].id

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-s3-endpoint"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_vpc_endpoint" "ecr_api" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.eks_nodes.id]
  private_dns_enabled = true

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-ecr-api-endpoint"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.eks_nodes.id]
  private_dns_enabled = true

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-ecr-dkr-endpoint"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_vpc_endpoint" "secretsmanager" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.eks_nodes.id]
  private_dns_enabled = true

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-secretsmanager-endpoint"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_vpc_endpoint" "cloudwatch_logs" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.eks_nodes.id]
  private_dns_enabled = true

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-cloudwatch-endpoint"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

resource "aws_vpc_endpoint" "sts" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.eks_nodes.id]
  private_dns_enabled = true

  tags = merge(var.common_tags, {
    Name            = "${var.project_name}-${var.environment}-sts-endpoint"
    Environment     = var.environment
    SecurityProfile = "hardened"
  })
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
