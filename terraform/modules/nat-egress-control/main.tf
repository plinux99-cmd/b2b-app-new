# Production NAT Egress Allowlist (Replace 0.0.0.0/0)
resource "aws_security_group" "nategress" {
  name_prefix = "${var.project_name}-nat-egress-"
  vpc_id      = var.vpc_id
  description = "Restricted NAT egress"

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Use configured allowlist for NAT egress. Default is ["0.0.0.0/0"],
    # but override `nat_egress_cidrs` to restrict outbound access in production.
    cidr_blocks = var.nat_egress_cidrs
  }

  tags = {
    Name        = "${var.project_name}-nat-egress"
    Environment = var.environment
  }
}

# SSM Session Manager (No SSH ports)
#resource "aws_security_group_rule" "ssm_ingress" {
#  type              = "ingress"
#  from_port         = 22  # SSM uses this internally
#  to_port           = 22
#  protocol          = "tcp"
#  cidr_blocks       = ["10.0.0.0/16"]  # VPC only
#  security_group_id = aws_security_group.nategress.id
#}
