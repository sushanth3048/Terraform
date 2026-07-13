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

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-alb-sg" })
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout               = var.idle_timeout

  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = aws_s3_bucket.alb_logs[0].id
      prefix  = "alb-logs"
      enabled = true
    }
  }

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-alb" })
}

# S3 Bucket for access logs
resource "aws_s3_bucket" "alb_logs" {
  count         = var.enable_access_logs ? 1 : 0
  bucket        = "${var.project}-${var.environment}-alb-logs"
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_policy" "alb_logs" {
  count  = var.enable_access_logs ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_elb_service_account.main.id}:root" }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.alb_logs[0].arn}/alb-logs/AWSLogs/*"
    }]
  })
}

data "aws_elb_service_account" "main" {}

# Target Groups
resource "aws_lb_target_group" "main" {
  for_each = var.target_groups

  name        = "${var.project}-${var.environment}-${each.key}"
  port        = each.value.port
  protocol    = each.value.protocol
  vpc_id      = var.vpc_id
  target_type = lookup(each.value, "target_type", "instance")

  health_check {
    enabled             = true
    healthy_threshold   = lookup(each.value, "healthy_threshold", 3)
    unhealthy_threshold = lookup(each.value, "unhealthy_threshold", 3)
    interval            = lookup(each.value, "health_check_interval", 30)
    matcher             = lookup(each.value, "health_check_matcher", "200")
    path                = lookup(each.value, "health_check_path", "/health")
    port                = "traffic-port"
    protocol            = each.value.protocol
    timeout             = lookup(each.value, "health_check_timeout", 5)
  }

  dynamic "stickiness" {
    for_each = lookup(each.value, "stickiness_enabled", false) ? [1] : []
    content {
      type            = "lb_cookie"
      cookie_duration = lookup(each.value, "cookie_duration", 86400)
      enabled         = true
    }
  }

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-${each.key}" })

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP Listener (redirects to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.https_certificate_arn != "" ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.https_certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = var.https_certificate_arn == "" ? [1] : []
      content {
        target_group {
          arn    = aws_lb_target_group.main[var.default_target_group].arn
          weight = 100
        }
      }
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  count             = var.https_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.https_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[var.default_target_group].arn
  }
}

# Listener Rules
resource "aws_lb_listener_rule" "main" {
  for_each = var.listener_rules

  listener_arn = var.https_certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[each.value.target_group_key].arn
  }

  dynamic "condition" {
    for_each = lookup(each.value, "path_patterns", null) != null ? [1] : []
    content {
      path_pattern {
        values = each.value.path_patterns
      }
    }
  }

  dynamic "condition" {
    for_each = lookup(each.value, "host_headers", null) != null ? [1] : []
    content {
      host_header {
        values = each.value.host_headers
      }
    }
  }
}
