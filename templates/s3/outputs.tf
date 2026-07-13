output "bucket_id" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  description = "The bucket domain name"
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket region-specific domain name"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

output "bucket_region" {
  description = "The AWS region where the bucket resides"
  value       = aws_s3_bucket.main.region
}

output "access_log_bucket_id" {
  description = "The name of the access log bucket (if created)"
  value       = try(aws_s3_bucket.access_log[0].id, null)
}
