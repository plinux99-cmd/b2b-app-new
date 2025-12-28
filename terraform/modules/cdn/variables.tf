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

