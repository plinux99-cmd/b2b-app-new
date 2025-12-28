locals {
  vpc_cidr = "10.0.0.0/16"

  azs = [
    "${var.aws_region}a",
    "${var.aws_region}b",
    "${var.aws_region}c",
  ]

  public_subnet_cidrs = [
    "10.0.1.0/24",
    "10.0.2.0/24",
  ]

  private_app_subnet_cidrs = [
    "10.0.10.0/24",
    "10.0.11.0/24",
    "10.0.12.0/24",
  ]
}

# Allow using an existing VPC (by ID) instead of creating a new one.
resource "aws_vpc" "this" {
  count                = var.existing_vpc_id == "" ? 1 : 0
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

locals {
  vpc_id = var.existing_vpc_id != "" ? var.existing_vpc_id : aws_vpc.this[0].id
}

resource "aws_internet_gateway" "this" {
  vpc_id = local.vpc_id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = {
    for k, v in {
      a = { cidr = local.public_subnet_cidrs[0], az = local.azs[0] }
      b = { cidr = local.public_subnet_cidrs[1], az = local.azs[1] }
    } : k => v
  }

  vpc_id                  = local.vpc_id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.project_name}-public-${each.key}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

resource "aws_subnet" "private_app" {
  for_each = {
    for k, v in {
      a = { cidr = local.private_app_subnet_cidrs[0], az = local.azs[0] }
      b = { cidr = local.private_app_subnet_cidrs[1], az = local.azs[1] }
      c = { cidr = local.private_app_subnet_cidrs[2], az = local.azs[2] }
    } : k => v
  }

  vpc_id            = local.vpc_id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name                                        = "${var.project_name}-private-app-${each.key}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    #  "kubernetes.io/role/elb"                = "1"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-public-rtb"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private_app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# NAT Gateway (High Availability)
resource "aws_eip" "nat" {
  for_each = (var.create_nat_gateways || var.retain_nat_eips) ? { for k, v in aws_subnet.public : k => v } : {}

  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-${each.key}-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  for_each = var.create_nat_gateways ? { for k, v in aws_subnet.public : k => v } : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name = "${var.project_name}-nat-${each.key}"
  }
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private_app

  vpc_id = local.vpc_id

  dynamic "route" {
    for_each = var.create_nat_gateways ? [1] : []
    content {
      cidr_block    = "0.0.0.0/0"
      nat_gateway_id = try(aws_nat_gateway.nat[each.key].id, aws_nat_gateway.nat["a"].id)
    }
  }

  tags = {
    Name = "${var.project_name}-private-rtb-${each.key}"
  }
}

#resource "aws_route_table_association" "private" {
#  for_each       = aws_subnet.private_app
#  subnet_id      = each.value.id
#  route_table_id = aws_route_table.private[each.key].id
#}

# Security Groups (Production hardened)
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-sg-"
  description = "ALB security group"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_security_group" "vpc_link" {
  name_prefix = "${var.project_name}-vpc-link-sg-"
  description = "API Gateway VPC Link to ALB"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-vpc-link-sg"
  }
}
