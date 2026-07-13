output "table_id" {
  description = "The name of the DynamoDB table"
  value       = aws_dynamodb_table.main.id
}

output "table_arn" {
  description = "The ARN of the DynamoDB table"
  value       = aws_dynamodb_table.main.arn
}

output "table_name" {
  description = "The full name of the DynamoDB table"
  value       = aws_dynamodb_table.main.name
}

output "stream_arn" {
  description = "The ARN of the DynamoDB stream (if enabled)"
  value       = aws_dynamodb_table.main.stream_arn
}

output "stream_label" {
  description = "The timestamp of the DynamoDB stream (if enabled)"
  value       = aws_dynamodb_table.main.stream_label
}
