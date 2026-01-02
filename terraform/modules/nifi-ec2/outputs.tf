output "instance_id" {
  description = "ID of the NiFi EC2 instance"
  value       = aws_instance.nifi.id
}

output "instance_private_ip" {
  description = "Private IP address of the NiFi instance"
  value       = aws_instance.nifi.private_ip
}

output "instance_public_ip" {
  description = "Public IP address of the NiFi instance"
  value       = aws_instance.nifi.public_ip
}

output "security_group_id" {
  description = "Security group ID for NiFi instance"
  value       = aws_security_group.nifi.id
}

output "ebs_volume_id" {
  description = "EBS volume ID for NiFi data storage"
  value       = aws_ebs_volume.nifi_data.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to the NiFi instance"
  value       = aws_iam_role.nifi.arn
}

output "iam_role_name" {
  description = "Name of the IAM role attached to the NiFi instance"
  value       = aws_iam_role.nifi.name
}

output "dlm_policy_id" {
  description = "ID of the DLM lifecycle policy for snapshots"
  value       = aws_dlm_lifecycle_policy.nifi_snapshots.id
}

output "nifi_web_ui_url" {
  description = "NiFi Web UI URL (HTTP)"
  value       = "http://${aws_instance.nifi.private_ip}:8080/nifi"
}

output "nifi_secure_web_ui_url" {
  description = "NiFi Secure Web UI URL (HTTPS)"
  value       = "https://${aws_instance.nifi.private_ip}:8443/nifi"
}
