variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "environment" {
  description = "Environment (prod/staging/dev)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
