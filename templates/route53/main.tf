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
  region = var.aws_region
}

# Hosted Zone
resource "aws_route53_zone" "main" {
  count = var.create_zone ? 1 : 0

  name    = var.domain_name
  comment = "${var.project} ${var.environment} hosted zone"

  dynamic "vpc" {
    for_each = var.private_zone ? var.private_zone_vpc_ids : []
    content {
      vpc_id = vpc.value
    }
  }

  tags = var.tags
}

data "aws_route53_zone" "existing" {
  count        = var.create_zone ? 0 : 1
  name         = var.domain_name
  private_zone = var.private_zone
}

locals {
  zone_id = var.create_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.existing[0].zone_id
}

# DNS Records
resource "aws_route53_record" "main" {
  for_each = var.records

  zone_id = local.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = lookup(each.value, "alias", null) == null ? lookup(each.value, "ttl", 300) : null
  records = lookup(each.value, "alias", null) == null ? each.value.records : null

  dynamic "alias" {
    for_each = lookup(each.value, "alias", null) != null ? [each.value.alias] : []
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = lookup(alias.value, "evaluate_target_health", true)
    }
  }

  dynamic "weighted_routing_policy" {
    for_each = lookup(each.value, "weight", null) != null ? [1] : []
    content {
      weight = each.value.weight
    }
  }

  dynamic "failover_routing_policy" {
    for_each = lookup(each.value, "failover", null) != null ? [1] : []
    content {
      type = each.value.failover
    }
  }

  set_identifier = lookup(each.value, "set_identifier", null)

  health_check_id = lookup(each.value, "health_check_key", null) != null ? aws_route53_health_check.main[each.value.health_check_key].id : null
}

# Health Checks
resource "aws_route53_health_check" "main" {
  for_each = var.health_checks

  fqdn              = lookup(each.value, "fqdn", null)
  ip_address        = lookup(each.value, "ip_address", null)
  port              = lookup(each.value, "port", 443)
  type              = each.value.type
  resource_path     = lookup(each.value, "resource_path", "/")
  failure_threshold = lookup(each.value, "failure_threshold", 3)
  request_interval  = lookup(each.value, "request_interval", 30)

  enable_sni = lookup(each.value, "enable_sni", true)

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-${each.key}" })
}

# ACM Certificate (with DNS validation)
resource "aws_acm_certificate" "main" {
  count = var.create_acm_certificate ? 1 : 0

  domain_name               = var.domain_name
  subject_alternative_names = var.certificate_san
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.create_acm_certificate ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.zone_id
}

resource "aws_acm_certificate_validation" "main" {
  count                   = var.create_acm_certificate ? 1 : 0
  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
