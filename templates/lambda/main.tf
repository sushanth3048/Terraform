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

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc" {
  count      = var.deploy_in_vpc ? 1 : 0
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "custom" {
  count  = var.custom_policy != "" ? 1 : 0
  name   = "${var.function_name}-custom-policy"
  role   = aws_iam_role.lambda.id
  policy = var.custom_policy
}

# Security Group (when deployed in VPC)
resource "aws_security_group" "lambda" {
  count       = var.deploy_in_vpc ? 1 : 0
  name        = "${var.function_name}-sg"
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.function_name}-sg" })
}

# Lambda Layer (optional)
resource "aws_lambda_layer_version" "main" {
  count               = var.create_layer ? 1 : 0
  layer_name          = "${var.function_name}-layer"
  filename            = var.layer_filename
  compatible_runtimes = [var.runtime]

  lifecycle {
    create_before_destroy = true
  }
}

# Lambda Function
resource "aws_lambda_function" "main" {
  function_name = var.function_name
  description   = var.description
  role          = aws_iam_role.lambda.arn
  runtime       = var.runtime
  handler       = var.handler
  timeout       = var.timeout
  memory_size   = var.memory_size
  architectures = [var.architecture]

  # Deploy from local file or S3
  filename         = var.s3_bucket == "" ? var.filename : null
  source_code_hash = var.s3_bucket == "" ? filebase64sha256(var.filename) : null
  s3_bucket        = var.s3_bucket != "" ? var.s3_bucket : null
  s3_key           = var.s3_bucket != "" ? var.s3_key : null

  layers = var.create_layer ? concat([aws_lambda_layer_version.main[0].arn], var.additional_layer_arns) : var.additional_layer_arns

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = var.deploy_in_vpc ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = [aws_security_group.lambda[0].id]
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn != "" ? [1] : []
    content {
      target_arn = var.dead_letter_target_arn
    }
  }

  dynamic "tracing_config" {
    for_each = var.enable_xray ? [1] : []
    content {
      mode = "Active"
    }
  }

  reserved_concurrent_executions = var.reserved_concurrency

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.basic
  ]

  tags = var.tags
}

# Auto-scaling for provisioned concurrency
resource "aws_lambda_provisioned_concurrency_config" "main" {
  count                             = var.provisioned_concurrency > 0 ? 1 : 0
  function_name                     = aws_lambda_function.main.function_name
  qualifier                         = aws_lambda_alias.live[0].name
  provisioned_concurrent_executions = var.provisioned_concurrency
}

# Lambda Alias
resource "aws_lambda_alias" "live" {
  count            = var.provisioned_concurrency > 0 ? 1 : 0
  name             = "live"
  description      = "Live alias for provisioned concurrency"
  function_name    = aws_lambda_function.main.function_name
  function_version = aws_lambda_function.main.version
}

# Event Source Mappings (for SQS, DynamoDB Streams, Kinesis)
resource "aws_lambda_event_source_mapping" "main" {
  for_each = var.event_source_mappings

  event_source_arn  = each.value.event_source_arn
  function_name     = aws_lambda_function.main.arn
  starting_position = lookup(each.value, "starting_position", null)
  batch_size        = lookup(each.value, "batch_size", 10)
  enabled           = lookup(each.value, "enabled", true)
}

# Function URL (optional)
resource "aws_lambda_function_url" "main" {
  count              = var.create_function_url ? 1 : 0
  function_name      = aws_lambda_function.main.function_name
  authorization_type = var.function_url_auth_type

  dynamic "cors" {
    for_each = var.function_url_cors != null ? [var.function_url_cors] : []
    content {
      allow_origins = cors.value.allow_origins
      allow_methods = cors.value.allow_methods
      allow_headers = cors.value.allow_headers
    }
  }
}
