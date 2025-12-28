variable "name_suffix" {
  type        = string
  description = "Env suffix, e.g. dev/test/prod"
}

variable "api_stage_arn" {
  type        = string
  description = "API Gateway stage execution ARN for WAF association"
  default     = ""
}
