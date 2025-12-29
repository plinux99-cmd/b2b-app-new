data "aws_region" "current" {}

resource "aws_apigatewayv2_api" "this" {
  name                       = "${var.project_name}-apigw-${var.environment}"
  protocol_type              = "HTTP"
  route_selection_expression = "$request.method $request.path"

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["content-type", "authorization"]
    allow_methods     = ["GET", "POST", "OPTIONS", "PUT", "DELETE", "PATCH"]
    allow_origins     = var.cors_allow_origins
    max_age           = 3600
  }
}

resource "aws_apigatewayv2_vpc_link" "alb_link" {
  name               = "${var.project_name}-vpc-link-${var.environment}"
  security_group_ids = [var.vpc_link_sg_id]
  subnet_ids         = var.vpc_link_subnet_ids
}
// Create integration and routes only when explicitly enabled to avoid
// `count` depending on resource attributes that are unknown until apply.
resource "aws_apigatewayv2_integration" "alb_proxy" {
  count            = var.create_integration ? 1 : 0
  api_id           = aws_apigatewayv2_api.this.id
  integration_type = "HTTP_PROXY"
  connection_type  = "VPC_LINK"
  connection_id    = aws_apigatewayv2_vpc_link.alb_link.id
  # For VPC_LINK, integration_uri MUST be an ALB listener ARN or Cloud Map service ARN
  integration_uri        = var.alb_listener_arn != "" ? var.alb_listener_arn : ""
  integration_method     = "ANY"
  payload_format_version = "1.0"
  timeout_milliseconds   = 29000
}

locals {
  # Protected routes (require Lambda authorizer)
  # These services require authentication: assetservice, flightservice, paxservice, notificationservice
  protected_routes = [
    "ANY /assetservice",
    "ANY /assetservice/{proxy+}",
    "ANY /flightservice",
    "ANY /flightservice/{proxy+}",
    "ANY /paxservice",
    "ANY /paxservice/{proxy+}",
    "ANY /notificationservice",
    "ANY /notificationservice/{proxy+}",
  ]
  
  # Public routes (no authorization required)
  # These are public endpoints available without authentication
  public_routes = [
    "ANY /authservice",
    "ANY /authservice/{proxy+}",
    "POST /data",
    "GET /broadcast",
    "POST /client-login",
  ]
  
  # API paths from CDN (converted to ANY method for all HTTP verbs)
  # These are public paths that come from CDN configuration
  api_path_routes = [for path in var.api_paths : "ANY ${path}"]
}

resource "aws_apigatewayv2_authorizer" "lambda" {
  count                            = var.create_authorizer ? 1 : 0
  api_id                           = aws_apigatewayv2_api.this.id
  authorizer_type                  = "REQUEST"
  authorizer_uri                   = "arn:aws:apigateway:${data.aws_region.current.id}:lambda:path/2015-03-31/functions/${var.authorizer_lambda_arn}/invocations"
  name                             = var.authorizer_name != "" ? var.authorizer_name : "${var.project_name}-authorizer"
  identity_sources                 = var.authorizer_identity_sources
  authorizer_payload_format_version = var.authorizer_payload_version
  authorizer_result_ttl_in_seconds = var.authorizer_result_ttl_in_seconds
  enable_simple_responses          = false
}

data "aws_caller_identity" "current" {}

resource "aws_apigatewayv2_route" "protected" {
  for_each           = var.create_integration ? toset(local.protected_routes) : toset([])
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = each.key
  target             = "integrations/${aws_apigatewayv2_integration.alb_proxy[0].id}"
  authorization_type = var.create_authorizer ? "CUSTOM" : "NONE"
  authorizer_id      = var.create_authorizer ? aws_apigatewayv2_authorizer.lambda[0].id : null
}

resource "aws_apigatewayv2_route" "api_paths" {
  for_each           = var.create_integration ? toset(local.api_path_routes) : toset([])
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = each.key
  target             = "integrations/${aws_apigatewayv2_integration.alb_proxy[0].id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "public" {
  for_each           = var.create_integration ? toset(local.public_routes) : toset([])
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = each.key
  target             = "integrations/${aws_apigatewayv2_integration.alb_proxy[0].id}"
  authorization_type = "NONE"
}

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${aws_apigatewayv2_api.this.name}"
  retention_in_days = 90
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage_name
  auto_deploy = true

  default_route_settings {
    detailed_metrics_enabled = true
    throttling_burst_limit   = var.throttling_burst_limit
    throttling_rate_limit    = var.throttling_rate_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId           = "$context.requestId"
      ip                  = "$context.identity.sourceIp"
      status              = "$context.status"
      integrationStatus   = "$context.integrationStatus"
      integrationErrorMsg = "$context.integrationErrorMessage"
      errorMsg            = "$context.error.message"
      errorMsgString      = "$context.error.messageString"
    })
  }
}

# Optional custom domain and API mapping
resource "aws_apigatewayv2_domain_name" "custom" {
  count                = var.create_custom_domain ? 1 : 0
  domain_name          = var.custom_domain_name
  domain_name_configuration {
    certificate_arn = var.custom_domain_acm_cert_arn
    endpoint_type   = var.custom_domain_endpoint_type
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "custom" {
  count           = var.create_custom_domain ? 1 : 0
  api_id          = aws_apigatewayv2_api.this.id
  domain_name     = aws_apigatewayv2_domain_name.custom[0].domain_name
  stage           = aws_apigatewayv2_stage.default.name
  api_mapping_key = var.custom_domain_base_path
}