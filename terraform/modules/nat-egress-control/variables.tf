variable "project_name" {
  type        = string
  description = "Project name for tagging"
}

variable "environment" {
  type        = string
  description = "Environment (prod/stage/dev)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where NAT egress is enforced"
}

variable "nat_egress_cidrs" {
  type        = list(string)
  description = "Allowed CIDR blocks for outbound internet traffic"
  #  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  default = ["0.0.0.0/0"]
}
