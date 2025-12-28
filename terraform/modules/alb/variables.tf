variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_groups" {
  type = list(string)
}

variable "target_group_port" {
  description = "Port the ALB forwards to inside the VPC"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Health check path for the target group"
  type        = string
  default     = "/"
}
