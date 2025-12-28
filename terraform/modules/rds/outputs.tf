output "db_endpoint" {
  value       = aws_db_instance.this.endpoint
  description = "RDS database endpoint"
}

output "db_name" {
  value       = aws_db_instance.this.db_name
  description = "RDS database name"
}

output "db_username" {
  value       = var.db_username
  description = "RDS database username"
}

output "secret_arn" {
  value       = var.create_secrets ? aws_secretsmanager_secret.db_credentials[0].arn : var.secret_arn
  description = "ARN of the Secrets Manager secret (either created by this module or provided)"
}

output "security_group_id" {
  value       = aws_security_group.postgres.id
  description = "RDS security group ID"
}
