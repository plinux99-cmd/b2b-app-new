output "nategress_sg_id" {
  description = "Security group ID used to restrict NAT egress"
  value       = aws_security_group.nategress.id
}
