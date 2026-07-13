output "alb_id" {
  description = "The ID of the Application Load Balancer"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the ALB (for Route53 alias records)"
  value       = aws_lb.main.zone_id
}

output "security_group_id" {
  description = "The ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "http_listener_arn" {
  description = "The ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "The ARN of the HTTPS listener (if created)"
  value       = try(aws_lb_listener.https[0].arn, null)
}

output "target_group_arns" {
  description = "Map of target group name to ARN"
  value       = { for k, tg in aws_lb_target_group.main : k => tg.arn }
}
