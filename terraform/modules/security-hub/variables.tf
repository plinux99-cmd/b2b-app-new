variable "project_name" {
  description = "Project identifier"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "auto_enable_controls" {
  description = "Auto enable controls"
  type        = bool
  default     = true
}

variable "tags" {
  type = map(string)
}