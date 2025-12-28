data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

########################
# WAF for API Gateway (REGIONAL)
########################

resource "aws_wafv2_web_acl" "this" {
  name        = "aerowise-${var.name_suffix}-waf-api"
  description = "Managed WAF for API Gateway ${var.name_suffix}"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "aerowise-${var.name_suffix}-waf-api"
  }

  # Rule 1: CommonRuleSet
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "api-common-rules"
    }
  }

  # Rule 2: KnownBadInputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "api-known-bad-inputs"
    }
  }
}

########################
# Associate this WAF with HTTP API v2
########################

resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = var.api_stage_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}


