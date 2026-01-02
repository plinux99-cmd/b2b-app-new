variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (prod/staging/dev)"
  type        = string
}

variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type    = string
  default = "1.33"
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "nodegroup_name" {
  type = string
}

variable "desired_size" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 4
}

variable "instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}
variable "nat_egress_sg_id" {
  description = "Security group ID that enforces NAT egress policy"
  type        = string
}

variable "endpoint_public_access" {
  description = "Enable public API endpoint access"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to access EKS public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
  default     = "10.0.0.0/16"
}

