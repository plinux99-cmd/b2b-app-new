variable "project_name" {
  type        = string
  description = "Project name for resource naming"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name for tags"
}

variable "existing_vpc_id" {
  type        = string
  description = "Optional: use an existing VPC instead of creating a new one. Provide the VPC ID or leave empty to create a new VPC."
  default     = ""
}

variable "create_nat_gateways" {
  type        = bool
  description = "Whether to create NAT gateways and EIPs for private subnet egress. Disable to proceed without NAT (no internet egress from private subnets)."
  default     = true
}

variable "retain_nat_eips" {
  type        = bool
  description = "When NAT is disabled, retain existing NAT EIPs to avoid destroy attempts (useful when lacking EIP permissions)."
  default     = true
}

