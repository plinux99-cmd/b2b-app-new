output "api_id" {
  value = aws_apigatewayv2_api.this.id
}

output "stage_name" {
  description = "HTTP API stage name"
  value       = aws_apigatewayv2_stage.default.name
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.this.api_endpoint
}

output "vpc_link_id" {
  value = aws_apigatewayv2_vpc_link.alb_link.id
}

output "execution_arn" {
  description = "Execution ARN for the API stage (useful for WAF associations)."
  # Use region `id` to avoid deprecated attribute usage
  value = "arn:aws:apigateway:${data.aws_region.current.id}::/apis/${aws_apigatewayv2_api.this.id}/stages/${aws_apigatewayv2_stage.default.name}"
}

output "authorizer_id" {
  description = "Lambda authorizer ID (if created)."
  value       = length(aws_apigatewayv2_authorizer.lambda) > 0 ? aws_apigatewayv2_authorizer.lambda[0].id : ""
}

output "custom_domain_name" {
  description = "Custom domain name (if created)."
  value       = length(aws_apigatewayv2_domain_name.custom) > 0 ? aws_apigatewayv2_domain_name.custom[0].domain_name : ""
}

output "custom_domain_target" {
  description = "API Gateway domain name for DNS alias (if created)."
  value       = length(aws_apigatewayv2_domain_name.custom) > 0 ? aws_apigatewayv2_domain_name.custom[0].domain_name_configuration[0].target_domain_name : ""
}