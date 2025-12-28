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
  # ALB managed by Kubernetes Ingress Controller; skip lookup during destroy
  value = local.ingress_alb_hostname != "" ? "arn:aws:elasticloadbalancing:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:listener/app/k8s-mobileap-internal-63a6eb7efe/*" : ""
}

output "alb_dns_name" {
  description = "Internal ALB DNS name for VPC Link integration"
  value       = local.ingress_alb_hostname
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

output "waf_api_arn" {
  description = "API Gateway WAF ARN (if created)"
  value       = var.create_waf_api ? module.waf_api[0].web_acl_arn : ""
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
