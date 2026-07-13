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

# KMS Key for encryption
resource "aws_kms_key" "messaging" {
  count                   = var.encrypt_at_rest ? 1 : 0
  description             = "KMS key for SNS/SQS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = var.tags
}

# ──────────────────────────────────────────────
# SNS Topics
# ──────────────────────────────────────────────
resource "aws_sns_topic" "main" {
  for_each = var.sns_topics

  name                        = "${var.project}-${var.environment}-${each.key}${each.value.fifo ? ".fifo" : ""}"
  display_name                = lookup(each.value, "display_name", each.key)
  fifo_topic                  = lookup(each.value, "fifo", false)
  content_based_deduplication = lookup(each.value, "content_based_deduplication", false)
  kms_master_key_id           = var.encrypt_at_rest ? aws_kms_key.messaging[0].id : null

  tags = var.tags
}

resource "aws_sns_topic_policy" "main" {
  for_each = { for k, v in var.sns_topics : k => v if lookup(v, "policy", "") != "" }

  arn    = aws_sns_topic.main[each.key].arn
  policy = each.value.policy
}

# ──────────────────────────────────────────────
# SQS Queues
# ──────────────────────────────────────────────
resource "aws_sqs_queue" "deadletter" {
  for_each = { for k, v in var.sqs_queues : k => v if lookup(v, "enable_dlq", true) }

  name                        = "${var.project}-${var.environment}-${each.key}-dlq${lookup(each.value, "fifo", false) ? ".fifo" : ""}"
  fifo_queue                  = lookup(each.value, "fifo", false)
  message_retention_seconds   = 1209600  # 14 days
  kms_master_key_id           = var.encrypt_at_rest ? aws_kms_key.messaging[0].id : null

  tags = var.tags
}

resource "aws_sqs_queue" "main" {
  for_each = var.sqs_queues

  name                        = "${var.project}-${var.environment}-${each.key}${lookup(each.value, "fifo", false) ? ".fifo" : ""}"
  fifo_queue                  = lookup(each.value, "fifo", false)
  content_based_deduplication = lookup(each.value, "fifo", false) ? lookup(each.value, "content_based_deduplication", false) : null

  visibility_timeout_seconds  = lookup(each.value, "visibility_timeout", 30)
  message_retention_seconds   = lookup(each.value, "retention_seconds", 345600)  # 4 days
  max_message_size            = lookup(each.value, "max_message_size", 262144)   # 256KB
  delay_seconds               = lookup(each.value, "delay_seconds", 0)
  receive_wait_time_seconds   = lookup(each.value, "receive_wait_time", 0)

  kms_master_key_id = var.encrypt_at_rest ? aws_kms_key.messaging[0].id : null

  dynamic "redrive_policy" {
    for_each = lookup(each.value, "enable_dlq", true) ? [1] : []
    content {
      deadLetterTargetArn = aws_sqs_queue.deadletter[each.key].arn
      maxReceiveCount     = lookup(each.value, "max_receive_count", 3)
    }
  }

  tags = var.tags
}

resource "aws_sqs_queue_policy" "main" {
  for_each = { for k, v in var.sqs_queues : k => v if lookup(v, "policy", "") != "" }

  queue_url = aws_sqs_queue.main[each.key].id
  policy    = each.value.policy
}

# SNS → SQS Subscriptions
resource "aws_sns_topic_subscription" "sqs" {
  for_each = var.sns_sqs_subscriptions

  topic_arn            = aws_sns_topic.main[each.value.topic_key].arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.main[each.value.queue_key].arn
  raw_message_delivery = lookup(each.value, "raw_message_delivery", false)
  filter_policy        = lookup(each.value, "filter_policy", null)
}

# Allow SNS to send messages to SQS
resource "aws_sqs_queue_policy" "allow_sns" {
  for_each = {
    for k, v in var.sns_sqs_subscriptions : "${v.topic_key}-${v.queue_key}" => v
  }

  queue_url = aws_sqs_queue.main[each.value.queue_key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.main[each.value.queue_key].arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_sns_topic.main[each.value.topic_key].arn
        }
      }
    }]
  })
}
