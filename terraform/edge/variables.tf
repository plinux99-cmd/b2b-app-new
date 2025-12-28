# CDN (test values)
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "cdn_name_suffix" {
  type    = string
  default = "sample"
}
# similarly, sample bucket name / origin path

variable "cdn_bucket_name" {
  type    = string
  default = "aerowise-frontend-sample"
}

variable "cdn_origin_path" {
  type    = string
  default = "/aerowise-web-app-sample"
}

variable "cdn_alt_domain" {
  type    = string
  default = "" # e.g. "app.example.com"
}

variable "acm_cert_arn" {
  type    = string
  default = "" # ACM cert in us-east-1 for CloudFront
}
variable "env" {
  type        = string
  default     = "sample"
  description = "Environment name"
}

