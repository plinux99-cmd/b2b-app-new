data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : "${var.project_name}-cloudtrail-${var.aws_region}"
}

# S3 Bucket (private, encrypted, versioning)
resource "aws_s3_bucket" "cloudtrail" {
  bucket        = local.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      # SECURITY: Use KMS CMK for CloudTrail encryption
      sse_algorithm     = var.kms_key_arn != null && var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != null && var.kms_key_arn != "" ? var.kms_key_arn : null
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# REQUIRED: S3 Bucket Policy for CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/cloudtrail/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# CloudTrail (multi-region, log validation)
resource "aws_cloudtrail" "this" {
  name                          = "${var.project_name}-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.this.arn}:*"
  cloud_watch_logs_role_arn  = var.cloudtrail_role_arn != "" ? var.cloudtrail_role_arn : module.cloudtrail_role[0].arn

  # Explicit dependency on bucket policy
  depends_on = [aws_s3_bucket_policy.cloudtrail]

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/cloudtrail/${var.project_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}

module "cloudtrail_policy" {
  source = "terraform-aws-modules/iam/aws//modules/iam-policy"

  name        = "${var.project_name}-cloudtrail-cloudwatch-policy"
  path        = "/"
  description = "Allow CloudTrail to put logs to CloudWatch Logs"

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Effect": "Allow",
        "Resource": "${aws_cloudwatch_log_group.this.arn}:*"
      }
    ]
  }
  EOF

  tags = var.tags
}

module "cloudtrail_role" {
  count  = var.cloudtrail_role_arn == "" ? 1 : 0
  source = "terraform-aws-modules/iam/aws//modules/iam-role"

  name = "${var.project_name}-cloudtrail-cloudwatch"

  # Ensure CloudTrail can assume this role by adding an explicit trust policy
  # with a valid SID so AWS accepts the assume-role policy.
  trust_policy_permissions = {
    cloudtrail_service = {
      sid = "CloudTrailAssumeRole"
      principals = [
        {
          type        = "Service"
          identifiers = ["cloudtrail.amazonaws.com"]
        }
      ]
      actions = ["sts:AssumeRole"]
      effect  = "Allow"
    }
  }

  policies = {
    cloudwatch = module.cloudtrail_policy.arn
  }

  tags = var.tags
}
