output "web_acl_arn" {
  description = "ARN of the WAFv2 Web ACL for API Gateway"
  value       = aws_wafv2_web_acl.this.arn
}
