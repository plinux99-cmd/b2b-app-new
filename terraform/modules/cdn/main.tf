# S3 bucket for static content
resource "aws_s3_bucket" "static_site" {
  bucket = var.bucket_name

  tags = {
    Name = "frontend-${var.name_suffix}"
  }
}

# S3 bucket policy for CloudFront OAC (no circular ref)
resource "aws_s3_bucket_policy" "static_site_policy" {
  bucket = aws_s3_bucket.static_site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontOAC"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.static_site.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.frontend.id}"
        }
      }
    }]
  })

  depends_on = [aws_s3_bucket.static_site]
}

# Origin Access Control for S3
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "frontend-oac-${var.name_suffix}-${var.env}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_caller_identity" "current" {}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  comment             = "frontend-${var.name_suffix}"
  default_root_object = "index.html"
  web_acl_id          = var.web_acl_id

  origin {
    domain_name              = aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_id                = "frontend-s3-origin-${var.name_suffix}"
    origin_path              = var.origin_path
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  # Optional API Gateway origin: used when api_origin_domain_name is provided.
  dynamic "origin" {
    for_each = length(trimspace(var.api_origin_domain_name)) > 0 ? [var.api_origin_domain_name] : []
    content {
      domain_name = origin.value
      origin_id   = "api-origin"

      custom_origin_config {
        origin_protocol_policy = "https-only"
        http_port              = 80
        https_port             = 443
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  aliases = var.alt_domain != "" ? [var.alt_domain] : []

  default_cache_behavior {
    target_origin_id       = "frontend-s3-origin-${var.name_suffix}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    compress               = true
  }

  # Route selected API paths through the API origin when configured.
  dynamic "ordered_cache_behavior" {
    for_each = length(trimspace(var.api_origin_domain_name)) > 0 && length(var.api_paths) > 0 ? var.api_paths : []
    content {
      path_pattern           = ordered_cache_behavior.value
      target_origin_id       = "api-origin"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods         = ["GET", "HEAD"]
      cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
      compress               = true
    }
  }

  custom_error_response {
    error_code            = 403
    response_code         = 403
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.acm_cert_arn == null || var.acm_cert_arn == "" ? true : false
    acm_certificate_arn            = var.acm_cert_arn != null && var.acm_cert_arn != "" ? var.acm_cert_arn : null
    ssl_support_method             = var.acm_cert_arn != null && var.acm_cert_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.acm_cert_arn != null && var.acm_cert_arn != "" ? "TLSv1.2_2021" : null
  }

  tags = {
    Name = "frontend-cf-${var.name_suffix}"
  }
}
