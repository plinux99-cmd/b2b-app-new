output "vpc_id" {
  value = module.network.vpc_id
}

output "private_app_subnet_ids" {
  value = module.network.private_app_subnet_ids
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "alb_http_listener_arn" {
  description = "ALB HTTP listener ARN auto-discovered from Kubernetes Ingress"
  value       = try(data.aws_lb_listener.ingress_http[0].arn, "")
}

output "ingress_alb_hostname" {
  description = "Internal ALB DNS name discovered from Kubernetes Ingress status"
  value       = local.ingress_alb_hostname
}

output "ingress_alb_arn" {
  description = "Internal ALB ARN auto-discovered from Kubernetes Ingress"
  value       = try(data.aws_lb.ingress_alb[0].arn, "")
}

output "effective_alb_listener_arn" {
  description = "Effective ALB listener ARN used by API Gateway (auto-discovered or from variable)"
  value       = local.effective_alb_listener_arn
}

// Removed `alb_arn` placeholder to avoid confusion. ALB is managed by Ingress Controller.

// The target group is managed dynamically by the Ingress Controller; no static TG ARN is exported.

output "cdn_distribution_id" {
  description = "CloudFront distribution ID (created when create_cdn = true)"
  value       = var.create_cdn ? module.cdn_static[0].cloudfront_distribution_id : ""
}

output "cdn_domain_name" {
  description = "CloudFront distribution domain name"
  value       = var.create_cdn ? module.cdn_static[0].cloudfront_domain_name : ""
}

output "waf_cdn_arn" {
  description = "CloudFront WAF ARN (if created)"
  value       = var.create_waf_cdn && var.create_cdn ? module.waf_cdn[0].web_acl_arn : ""
}

output "alb_sg_id" {
  value = module.network.alb_sg_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "api_id" {
  description = "API Gateway API id"
  value       = module.api_gateway.api_id
}

output "api_endpoint" {
  description = "API Gateway invoke URL"
  value       = module.api_gateway.api_endpoint
}

output "api_vpc_link_id" {
  description = "API Gateway VPC Link id"
  value       = module.api_gateway.vpc_link_id
}

output "api_execution_arn" {
  description = "API Gateway execution ARN (stage)"
  value       = module.api_gateway.execution_arn
}

# NiFi EC2 Outputs
output "nifi_instance_id" {
  description = "NiFi EC2 instance ID"
  value       = var.create_nifi_ec2 ? module.nifi_ec2[0].instance_id : ""
}

output "nifi_instance_private_ip" {
  description = "NiFi EC2 private IP address"
  value       = var.create_nifi_ec2 ? module.nifi_ec2[0].instance_private_ip : ""
}

output "nifi_instance_public_ip" {
  description = "NiFi EC2 public IP address (if enabled)"
  value       = var.create_nifi_ec2 ? module.nifi_ec2[0].instance_public_ip : ""
}

output "nifi_ebs_volume_id" {
  description = "NiFi data EBS volume ID"
  value       = var.create_nifi_ec2 ? module.nifi_ec2[0].ebs_volume_id : ""
}

output "nifi_security_group_id" {
  description = "NiFi security group ID"
  value       = var.create_nifi_ec2 ? module.nifi_ec2[0].security_group_id : ""
}

output "nifi_web_ui_url" {
  description = "NiFi Web UI URL (HTTP)"
  value       = var.create_nifi_ec2 ? module.nifi_ec2[0].nifi_web_ui_url : ""
}

output "nifi_secure_web_ui_url" {
  description = "NiFi Secure Web UI URL (HTTPS)"
  value       = var.create_nifi_ec2 ? module.nifi_ec2[0].nifi_secure_web_ui_url : ""
}

output "nifi_dlm_policy_id" {
  description = "NiFi Data Lifecycle Manager snapshot policy ID"
  value       = var.create_nifi_ec2 ? module.nifi_ec2[0].dlm_policy_id : ""
}
