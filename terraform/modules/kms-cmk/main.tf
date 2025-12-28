resource "aws_kms_key" "app_secrets" {
  description             = "Aerowise app secrets DB/JWT"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM policies"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow RDS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-app-secrets-cmk"
    Environment = var.environment
    Project     = var.project_name
  }
}

data "aws_caller_identity" "current" {}


resource "aws_kms_alias" "app_secrets" {
  name          = "alias/${var.project_name}-app-secrets"
  target_key_id = aws_kms_key.app_secrets.key_id
}
