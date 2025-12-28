variable "project_name" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { 
  description = "VPC CIDR block (used as fallback for VPCE SG ingress)"
  type        = string
  default     = "10.0.0.0/16"
}
variable "vpc_link_sg_id" { type = string }
variable "private_route_table_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
// Removed: eks_node_sg_id is intentionally not consumed by this module to avoid
// circular dependencies. In production we create a dedicated aws_security_group_rule
// in the root module that authorizes the EKS node SG to reach the VPCE SG.

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (used as fallback for VPCE SG ingress)"
  type        = list(string)
  default     = []
}

variable "allow_private_subnet_cidr_fallback" {
  description = "Allow adding CIDR-based ingress to VPCE SG as a fallback when node SG cannot be used"
  type        = bool
  default     = true
}

variable "create_ecr_public_endpoint" {
  description = "Whether to create the ecr-public VPC endpoint (region-dependent)"
  type        = bool
  default     = false
}
