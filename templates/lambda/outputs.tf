output "function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.main.arn
}

output "function_invoke_arn" {
  description = "The ARN for invoking the Lambda function (used by API Gateway)"
  value       = aws_lambda_function.main.invoke_arn
}

output "function_version" {
  description = "The latest published version of the Lambda function"
  value       = aws_lambda_function.main.version
}

output "role_arn" {
  description = "The ARN of the Lambda IAM role"
  value       = aws_iam_role.lambda.arn
}

output "role_name" {
  description = "The name of the Lambda IAM role"
  value       = aws_iam_role.lambda.name
}

output "log_group_name" {
  description = "The name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "function_url" {
  description = "The URL of the Lambda function URL (if created)"
  value       = try(aws_lambda_function_url.main[0].function_url, null)
}

output "layer_arn" {
  description = "The ARN of the Lambda layer (if created)"
  value       = try(aws_lambda_layer_version.main[0].arn, null)
}
