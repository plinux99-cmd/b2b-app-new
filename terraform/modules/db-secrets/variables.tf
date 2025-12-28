variable "name" {
  description = "Secrets Manager name (e.g. aerowise-t1-db-credentials)"
  type        = string
}

variable "username" {
  description = "Initial DB username"
  type        = string
  sensitive   = true
}

variable "password" {
  description = "Initial DB password"
  type        = string
  sensitive   = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
variable "kms_key_arn" {
  description = "KMS CMK ARN for encrypting DB credentials"
  type        = string
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Environment prod"
}
variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "aerowise-t1"
}