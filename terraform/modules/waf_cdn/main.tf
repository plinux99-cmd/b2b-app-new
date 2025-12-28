data "aws_caller_identity" "current" {}

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

########################
# CloudFront-scope WAF for CDN
########################

resource "aws_wafv2_web_acl" "cdn" {
  name        = "aerowise-${var.name_suffix}-waf-cdn"
  description = "Managed WAF for static CloudFront CDN - ${var.name_suffix}"
  scope       = "CLOUDFRONT" # Global scope for CloudFront

  default_action {
    allow {}
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "aerowise-${var.name_suffix}-waf-cdn"
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
      metric_name                = "cdn-common-rules"
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
      metric_name                = "cdn-known-bad-inputs"
    }
  }

  # Rule 3: IP Reputation
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "cdn-ip-reputation"
    }
  }
}

########################
# CloudFront WAF
########################

