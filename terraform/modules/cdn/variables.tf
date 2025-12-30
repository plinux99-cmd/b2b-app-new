variable "name_suffix" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "origin_path" {
  type    = string
  default = ""
}

variable "alt_domain" {
  type    = string
  default = ""
}

variable "acm_cert_arn" {
  type    = string
  default = ""
}

variable "env" {
  type    = string
  default = "test"
}

variable "web_acl_id" {
  type        = string
  description = "WAFv2 WebACL ARN for CloudFront distribution"
  default     = ""
}

variable "api_origin_domain_name" {
  type        = string
  description = "Optional: API Gateway domain (e.g. et41gni1mk.execute-api.us-east-1.amazonaws.com) to route certain paths through CloudFront. When empty, only the S3 origin is used."
  default     = ""
}

variable "api_paths" {
  type        = list(string)
  description = "Path patterns that should be forwarded to the API origin (e.g. [/app-version/check, /assetservice*, /auth*])."
  default     = []
}

variable "index_html_source_path" {
  type        = string
  description = "Optional: Local path to index.html file to upload to S3 (e.g., '../edge/static/index.html'). Leave empty to skip automatic upload."
  default     = ""
}


