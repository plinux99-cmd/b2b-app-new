resource "aws_secretsmanager_secret" "this" {
  name        = "${var.name}-${random_string.suffix.result}"
  description = "RDS PostgreSQL master credentials for ${var.name}"

  # force CMK usage when provided
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30

  tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    Name        = var.name
  })
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}


resource "aws_secretsmanager_secret_version" "creds" {
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    username = var.username
    password = var.password
  })

}
