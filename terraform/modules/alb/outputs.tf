output "http_listener_arn" {
  value = aws_lb_listener.http.arn
}

output "arn" {
  description = "ALB ARN"
  value       = aws_lb.this.arn
}

output "dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "Target group ARN used for forwarding"
  value       = aws_lb_target_group.app.arn
}