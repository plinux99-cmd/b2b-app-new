output "s3_bucket_arn" {
  value       = aws_s3_bucket.cloudtrail.arn
  description = "CloudTrail S3 bucket ARN"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.cloudtrail.id
  description = "CloudTrail S3 bucket name"
}

output "trail_arn" {
  value       = aws_cloudtrail.this.arn
  description = "CloudTrail trail ARN"
}

output "log_group_name" {
  value       = aws_cloudwatch_log_group.this.name
  description = "CloudWatch log group name"
}
