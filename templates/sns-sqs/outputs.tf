output "sns_topic_arns" {
  description = "Map of SNS topic name to ARN"
  value       = { for k, t in aws_sns_topic.main : k => t.arn }
}

output "sqs_queue_urls" {
  description = "Map of SQS queue name to URL"
  value       = { for k, q in aws_sqs_queue.main : k => q.id }
}

output "sqs_queue_arns" {
  description = "Map of SQS queue name to ARN"
  value       = { for k, q in aws_sqs_queue.main : k => q.arn }
}

output "sqs_dlq_arns" {
  description = "Map of Dead Letter Queue name to ARN"
  value       = { for k, q in aws_sqs_queue.deadletter : k => q.arn }
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption (if created)"
  value       = try(aws_kms_key.messaging[0].arn, null)
}
