output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "public_subnet_ids" {
  description = "All public subnet IDs"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_app_subnet_ids" {
  description = "All private app subnet IDs"
  value       = [for s in aws_subnet.private_app : s.id]
}

output "alb_sg_id" {
  description = "ALB Security Group ID"
  value       = aws_security_group.alb.id
}

output "vpc_link_sg_id" {
  description = "VPC Link Security Group ID"
  value       = aws_security_group.vpc_link.id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = { for k, v in aws_nat_gateway.nat : k => v.id }
}
output "private_subnets" {
  description = "Private subnet IDs (private_app)"
  value       = [for s in aws_subnet.private_app : s.id]
}

output "private_app_subnet_cidrs" {
  description = "CIDR blocks for private app subnets"
  value       = local.private_app_subnet_cidrs
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_route_table_ids" {
  description = "Private route table IDs"
  value       = [for rt in aws_route_table.private : rt.id]
}

