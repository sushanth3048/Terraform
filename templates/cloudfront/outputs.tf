output "distribution_id" {
  description = "The CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  description = "The ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.arn
}

output "domain_name" {
  description = "The CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "hosted_zone_id" {
  description = "The CloudFront hosted zone ID (for Route53 alias records)"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "origin_access_control_id" {
  description = "The Origin Access Control ID (for S3 bucket policies)"
  value       = try(aws_cloudfront_origin_access_control.s3[0].id, null)
}

output "log_bucket_id" {
  description = "The ID of the access log bucket (if logging is enabled)"
  value       = try(aws_s3_bucket.logs[0].id, null)
}
