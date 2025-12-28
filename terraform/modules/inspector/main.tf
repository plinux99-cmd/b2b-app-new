resource "aws_inspector2_enabler" "this" {
  account_ids    = var.account_ids
  resource_types = var.resource_types
}