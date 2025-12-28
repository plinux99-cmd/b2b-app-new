variable "account_ids" {
  type        = list(string)
  description = "Account IDs for Inspector scanning"
}

variable "resource_types" {
  type        = list(string)
  default     = ["EC2", "ECR", "LAMBDA"]
  description = "Inspector resource types to scan"
}