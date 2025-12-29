variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.medium"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}

variable "create_secrets" {
  description = "Whether to create an RDS secret in this module. Set to false to provide an existing secret_arn."
  type        = bool
  default     = true
}

variable "secret_arn" {
  description = <<-DESC
If provided, use this existing Secrets Manager secret ARN instead of creating one.
This is useful when a previous secret with the same name is scheduled for deletion or already exists and you want Terraform to use it instead of creating a duplicate.
DESC
  type        = string
  default     = ""
}

variable "engine_version" {
  type    = string
  default = "17.6"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (set true to speed teardown; leave false in prod to retain a snapshot)."
  type        = bool
  default     = false
}

variable "storage_type" {
  description = "Storage type for RDS (gp2, gp3, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "iops" {
  description = "IOPS for gp3 storage type (3000-16000)"
  type        = number
  default     = 3000
}

variable "storage_throughput" {
  description = "Storage throughput in MB/s for gp3 (125-1000)"
  type        = number
  default     = 125
}

variable "eks_node_sg_id" {
  description = "Security group ID of EKS worker nodes"
  type        = string
}
