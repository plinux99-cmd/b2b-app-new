output "key_arn" {
  description = "KMS CMK ARN for app & DB secrets"
  value       = aws_kms_key.app_secrets.arn
}
