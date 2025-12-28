#data "aws_caller_identity" "current" {}

output "security_hub_arn" {
  value       = aws_securityhub_account.this.arn
  description = "Security Hub account ARN"
}
