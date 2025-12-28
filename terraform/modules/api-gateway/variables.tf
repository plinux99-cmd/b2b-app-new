variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_link_subnet_ids" {
  type = list(string)
}

variable "vpc_link_sg_id" {
  type = string
}

variable "alb_listener_arn" {
  type    = string
  default = ""
}

variable "integration_uri" {
  description = "Full URI used by API Gateway integration (e.g. http://<alb-dns>:80)"
  type        = string
  default     = ""
}

variable "create_integration" {
  description = "Whether to create the API Gateway integration and routes. If true, an integration will be created for the provided `integration_uri` or `alb_listener_arn`. Set this to true when creating an ALB in the same plan to avoid unknown count errors."
  type        = bool
  default     = false

  validation {
    condition     = var.create_integration == false || length(trimspace(var.integration_uri)) > 0 || length(trimspace(var.alb_listener_arn)) > 0
    error_message = "When create_integration is true, provide either integration_uri or alb_listener_arn."
  }
}

variable "throttling_burst_limit" {
  description = "Default route throttling burst limit (set >0 to avoid 429s)."
  type        = number
  default     = 1000
}

variable "throttling_rate_limit" {
  description = "Default route throttling steady-state RPS limit."
  type        = number
  default     = 500
}

variable "stage_name" {
  description = "Stage name for the HTTP API. Use $default to keep a stage-less base path."
  type        = string
  default     = "$default"
}

variable "cors_allow_origins" {
  type    = list(string)
  default = ["*"]
}


variable "create_authorizer" {
  description = "Whether to create a Lambda authorizer and attach it to protected routes."
  type        = bool
  default     = false

  validation {
    condition     = var.create_authorizer == false || length(trim(var.authorizer_lambda_arn)) > 0
    error_message = "When create_authorizer is true, authorizer_lambda_arn must be provided."
  }
}

variable "authorizer_lambda_arn" {
  description = "ARN of the Lambda function to use as the HTTP API Lambda authorizer. Required when create_authorizer = true."
  type        = string
  default     = ""
}

variable "authorizer_name" {
  description = "Name for the Lambda authorizer."
  type        = string
  default     = ""
}

variable "authorizer_identity_sources" {
  description = "Identity sources used by the authorizer (e.g., $request.header.Authorization)."
  type        = list(string)
  default     = ["$request.header.Authorization"]
}

variable "authorizer_payload_version" {
  description = "Payload format version sent to the authorizer Lambda."
  type        = string
  default     = "2.0"
}

variable "authorizer_result_ttl_in_seconds" {
  description = "Authorizer cache TTL in seconds (0 disables caching)."
  type        = number
  default     = 0
}

variable "create_custom_domain" {
  description = "Whether to create a custom domain and API mapping for this API."
  type        = bool
  default     = false
}

variable "custom_domain_name" {
  description = "Custom domain name for the API (e.g., api.example.com)."
  type        = string
  default     = ""
}

variable "custom_domain_acm_cert_arn" {
  description = "ACM certificate ARN for the custom domain (must be in the same region as the API)."
  type        = string
  default     = ""
}

variable "custom_domain_base_path" {
  description = "Base path for API mapping (empty string maps to root)."
  type        = string
  default     = ""
}

variable "custom_domain_endpoint_type" {
  description = "Endpoint type for the custom domain (REGIONAL or EDGE; HTTP APIs support REGIONAL)."
  type        = string
  default     = "REGIONAL"
}