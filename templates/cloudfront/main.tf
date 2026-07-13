terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"  # CloudFront and ACM require us-east-1
}

# Origin Access Control for S3 origins
resource "aws_cloudfront_origin_access_control" "s3" {
  count = var.s3_origin_bucket != "" ? 1 : 0

  name                              = "${var.project}-${var.environment}-oac"
  description                       = "OAC for ${var.project} ${var.environment}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Cache Policies
resource "aws_cloudfront_cache_policy" "main" {
  count = var.create_custom_cache_policy ? 1 : 0

  name        = "${var.project}-${var.environment}-cache-policy"
  default_ttl = var.cache_default_ttl
  max_ttl     = var.cache_max_ttl
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = var.cache_query_strings ? "all" : "none"
    }
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project}-${var.environment}"
  default_root_object = var.default_root_object
  price_class         = var.price_class
  aliases             = var.domain_aliases
  web_acl_id          = var.waf_web_acl_arn != "" ? var.waf_web_acl_arn : null

  # S3 Origin
  dynamic "origin" {
    for_each = var.s3_origin_bucket != "" ? [1] : []
    content {
      domain_name              = "${var.s3_origin_bucket}.s3.${var.s3_origin_region}.amazonaws.com"
      origin_id                = "S3-${var.s3_origin_bucket}"
      origin_access_control_id = aws_cloudfront_origin_access_control.s3[0].id
    }
  }

  # Custom (ALB/API/HTTP) Origins
  dynamic "origin" {
    for_each = var.custom_origins
    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.key

      custom_origin_config {
        http_port              = lookup(origin.value, "http_port", 80)
        https_port             = lookup(origin.value, "https_port", 443)
        origin_protocol_policy = lookup(origin.value, "protocol_policy", "https-only")
        origin_ssl_protocols   = ["TLSv1.2"]
      }

      dynamic "custom_header" {
        for_each = lookup(origin.value, "custom_headers", {})
        content {
          name  = custom_header.key
          value = custom_header.value
        }
      }
    }
  }

  # Default Cache Behavior
  default_cache_behavior {
    allowed_methods        = var.default_allowed_methods
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = var.default_origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = var.create_custom_cache_policy ? aws_cloudfront_cache_policy.main[0].id : var.cache_policy_id
    origin_request_policy_id = var.origin_request_policy_id != "" ? var.origin_request_policy_id : null

    dynamic "function_association" {
      for_each = var.viewer_request_function_arn != "" ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = var.viewer_request_function_arn
      }
    }
  }

  # Additional Cache Behaviors
  dynamic "ordered_cache_behavior" {
    for_each = var.ordered_cache_behaviors
    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      allowed_methods        = lookup(ordered_cache_behavior.value, "allowed_methods", ["GET", "HEAD"])
      cached_methods         = ["GET", "HEAD"]
      target_origin_id       = ordered_cache_behavior.value.origin_id
      viewer_protocol_policy = "redirect-to-https"
      compress               = true
      cache_policy_id        = lookup(ordered_cache_behavior.value, "cache_policy_id", "4135ea2d-6df8-44a3-9df3-4b5a84be39ad")  # CachingDisabled
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  viewer_certificate {
    acm_certificate_arn            = var.acm_certificate_arn != "" ? var.acm_certificate_arn : null
    ssl_support_method             = var.acm_certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.acm_certificate_arn != "" ? "TLSv1.2_2021" : null
    cloudfront_default_certificate = var.acm_certificate_arn == ""
  }

  dynamic "logging_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      include_cookies = false
      bucket          = "${aws_s3_bucket.logs[0].bucket}.s3.amazonaws.com"
      prefix          = "cloudfront-logs/"
    }
  }

  tags = var.tags
}

# S3 Bucket for logs
resource "aws_s3_bucket" "logs" {
  count         = var.enable_logging ? 1 : 0
  bucket        = "${var.project}-${var.environment}-cf-logs"
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  count  = var.enable_logging ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Allow CloudFront to write to S3 origin (bucket policy)
resource "aws_s3_bucket_policy" "origin" {
  count  = var.s3_origin_bucket != "" ? 1 : 0
  bucket = var.s3_origin_bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "arn:aws:s3:::${var.s3_origin_bucket}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
        }
      }
    }]
  })
}
