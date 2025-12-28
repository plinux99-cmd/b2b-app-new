variable "s3_bucket_arn" {
  type        = string
  default     = null
  description = "S3 bucket ARN for findings export"
}

variable "s3_kms_key_arn" {
  type        = string
  default     = null
  description = "KMS key for S3 encryption"
}
