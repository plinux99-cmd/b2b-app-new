data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Enable Security Hub
resource "aws_securityhub_account" "this" {
  enable_default_standards = false

}

# Subscribe to AWS Foundational Security Best Practices
resource "aws_securityhub_standards_subscription" "foundational_best_practices" {
  depends_on = [aws_securityhub_account.this]
  # Use the region `id` attribute to avoid deprecated `name` usage
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.id}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

# Subscribe to CIS AWS Foundations Benchmark v1.3.0
#resource "aws_securityhub_standards_subscription" "cis_foundations" {
#  depends_on    = [aws_securityhub_account.this]
#  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/1.3.0"
#}
