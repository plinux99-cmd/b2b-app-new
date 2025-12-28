variable "project_name" {
  type        = string
  description = "Project name for naming"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "s3_bucket_name" {
  type        = string
  default     = ""
  description = "Existing S3 bucket name (empty = auto-create)"
}

variable "log_retention_days" {
  type        = number
  default     = 365
  description = "CloudWatch log retention days"
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "KMS key for log encryption"
}

# Optional: use an existing IAM role instead of creating a new one
variable "cloudtrail_role_arn" {
  description = "ARN of an existing IAM role to use for CloudTrail CloudWatch Logs delivery. If set, the module will not create a new role."
  type        = string
  default     = ""
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
