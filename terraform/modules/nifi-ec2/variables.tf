variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for NiFi"
  type        = string
  default     = "m5.2xlarge"
}

variable "storage_size" {
  description = "Size of the EBS volume in GB"
  type        = number
  default     = 128
}

variable "ebs_volume_type" {
  description = "EBS volume type (gp3, gp2, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "ebs_device_name" {
  description = "Device name for the EBS volume"
  type        = string
  default     = "/dev/sdf"
}

variable "ebs_encryption_enabled" {
  description = "Enable EBS encryption"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for EBS encryption (optional)"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID where NiFi instance will be created"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for NiFi instance placement"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for NiFi instance"
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB for ingress rules"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/32"] # Change this to your IP or security group
}

variable "associate_public_ip" {
  description = "Associate a public IP address with the instance"
  type        = bool
  default     = true
}

variable "nifi_version" {
  description = "Apache NiFi version to install"
  type        = string
  default     = "1.25.0"
}

variable "snapshot_retention_count" {
  description = "Number of snapshots to retain"
  type        = number
  default     = 14 # Keep 14 daily snapshots (~2 weeks)
}

variable "alarm_actions" {
  description = "SNS topic ARNs for CloudWatch alarm notifications"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
