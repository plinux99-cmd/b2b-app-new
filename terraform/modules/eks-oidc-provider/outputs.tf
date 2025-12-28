output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL"
  value       = local.oidc_issuer_url
}

output "oidc_issuer_hostname" {
  description = "OIDC issuer hostname (without https://)"
  value       = local.oidc_issuer_hostname
}
