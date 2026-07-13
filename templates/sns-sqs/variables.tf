variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "encrypt_at_rest" {
  description = "Encrypt topics and queues with KMS"
  type        = bool
  default     = true
}

variable "sns_topics" {
  description = "Map of SNS topics to create"
  type = map(object({
    display_name                = optional(string, "")
    fifo                        = optional(bool, false)
    content_based_deduplication = optional(bool, false)
    policy                      = optional(string, "")
  }))
  default = {}
}

variable "sqs_queues" {
  description = "Map of SQS queues to create"
  type = map(object({
    fifo                        = optional(bool, false)
    content_based_deduplication = optional(bool, false)
    visibility_timeout          = optional(number, 30)
    retention_seconds           = optional(number, 345600)
    max_message_size            = optional(number, 262144)
    delay_seconds               = optional(number, 0)
    receive_wait_time           = optional(number, 0)
    enable_dlq                  = optional(bool, true)
    max_receive_count           = optional(number, 3)
    policy                      = optional(string, "")
  }))
  default = {}
}

variable "sns_sqs_subscriptions" {
  description = "Map of SNS to SQS subscriptions (fan-out pattern)"
  type = map(object({
    topic_key            = string
    queue_key            = string
    raw_message_delivery = optional(bool, false)
    filter_policy        = optional(string, null)
  }))
  default = {}
}

variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}
