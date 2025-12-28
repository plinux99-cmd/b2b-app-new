output "api_id" {
  value = module.api_gateway.api_id
}

output "api_endpoint" {
  value = "https://${module.api_gateway.api_id}.execute-api.${data.aws_region.current.name}.amazonaws.com"
}

output "cloudfront_domain_name" {
  value = module.cdn_static.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  value = module.cdn_static.cloudfront_distribution_id
}

output "cloudfront_distribution_arn" {
  value = module.cdn_static.cloudfront_distribution_arn
}
