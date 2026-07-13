output "zone_id" {
  description = "The hosted zone ID"
  value       = local.zone_id
}

output "zone_name_servers" {
  description = "Name servers for the hosted zone (only for newly created zones)"
  value       = var.create_zone ? aws_route53_zone.main[0].name_servers : null
}

output "record_fqdns" {
  description = "Map of record key to FQDN"
  value       = { for k, r in aws_route53_record.main : k => r.fqdn }
}

output "acm_certificate_arn" {
  description = "The ARN of the ACM certificate (if created)"
  value       = try(aws_acm_certificate.main[0].arn, null)
}

output "acm_certificate_status" {
  description = "The status of the ACM certificate (if created)"
  value       = try(aws_acm_certificate_validation.main[0].certificate_arn, null) != null ? "ISSUED" : null
}
