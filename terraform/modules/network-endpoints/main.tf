########################################
# SECURITY GROUP FOR INTERFACE ENDPOINTS
########################################
resource "aws_security_group" "vpce" {
  name        = "${var.project_name}-vpce-sg"
  description = "Allow EKS nodes to reach AWS VPC interface endpoints"
  vpc_id      = var.vpc_id

  # Allow HTTPS to the VPCEs. Prefer explicit private subnet CIDRs; if none are
  # provided and fallback is enabled, allow the VPC CIDR once. Distinct avoids
  # duplicate rules when subnet CIDRs repeat.
  dynamic "ingress" {
    for_each = length(var.private_subnet_cidrs) > 0 ? distinct(var.private_subnet_cidrs) : (var.allow_private_subnet_cidr_fallback ? [var.vpc_cidr] : [])
    content {
      description = length(var.private_subnet_cidrs) > 0 ? "HTTPS from private subnet CIDR" : "HTTPS from VPC CIDR (fallback)"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-vpce-sg"
  }
}

########################################
# INTERFACE VPC ENDPOINTS (EKS REQUIRED)
########################################

# SSM
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]

  tags = { Name = "${var.project_name}-ssm" }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]

  tags = { Name = "${var.project_name}-ssmmessages" }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]

  tags = { Name = "${var.project_name}-ec2messages" }
}

# ECR
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]

  tags = { Name = "${var.project_name}-ecr-api" }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]

  tags = { Name = "${var.project_name}-ecr-dkr" }
}

# ECR PUBLIC (public.ecr.aws) - some official images and addons are pulled from ECR Public.
# This endpoint helps nodes in private subnets pull images from ECR Public without NAT.
resource "aws_vpc_endpoint" "ecr_public" {
  count  = var.create_ecr_public_endpoint ? 1 : 0
  vpc_id = var.vpc_id
  # Some regions resolve ecr-public as a regional endpoint; the service name below
  # is the common form. If your region does not support ecr-public, this will
  # fail and you can disable/omit this resource.
  service_name        = "com.amazonaws.${var.aws_region}.ecr-public"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]

  tags = { Name = "${var.project_name}-ecr-public" }
}

# STS (IRSA REQUIRED)
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]

  tags = { Name = "${var.project_name}-sts" }
}

# CloudWatch
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]

  tags = { Name = "${var.project_name}-logs" }
}

resource "aws_vpc_endpoint" "monitoring" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.monitoring"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]

  tags = { Name = "${var.project_name}-monitoring" }
}

# Secrets Manager
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]

  tags = { Name = "${var.project_name}-secretsmanager" }
}

########################################
# S3 GATEWAY ENDPOINT (ECR IMAGE LAYERS)
########################################
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids

  tags = { Name = "${var.project_name}-s3" }
}

########################################
# Outputs
########################################
output "vpce_security_group_id" {
  value       = aws_security_group.vpce.id
  description = "Security group used by interface VPC endpoints"
}

output "vpce_ids" {
  value = {
    ssm         = aws_vpc_endpoint.ssm.id
    ssmmessages = aws_vpc_endpoint.ssmmessages.id
    ec2messages = aws_vpc_endpoint.ec2messages.id
    ecr_api     = aws_vpc_endpoint.ecr_api.id
    ecr_dkr     = aws_vpc_endpoint.ecr_dkr.id
    # ecr_public may be absent
    ecr_public     = try(aws_vpc_endpoint.ecr_public[0].id, "")
    sts            = aws_vpc_endpoint.sts.id
    logs           = aws_vpc_endpoint.logs.id
    monitoring     = aws_vpc_endpoint.monitoring.id
    secretsmanager = aws_vpc_endpoint.secretsmanager.id
    s3             = aws_vpc_endpoint.s3.id
  }
  description = "Map of VPC endpoint ids"
}