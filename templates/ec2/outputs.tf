output "instance_ids" {
  description = "List of EC2 instance IDs"
  value       = aws_instance.main[*].id
}

output "instance_private_ips" {
  description = "List of private IP addresses of EC2 instances"
  value       = aws_instance.main[*].private_ip
}

output "instance_public_ips" {
  description = "List of public IP addresses of EC2 instances"
  value       = aws_instance.main[*].public_ip
}

output "security_group_id" {
  description = "The ID of the EC2 security group"
  value       = aws_security_group.ec2.id
}

output "iam_role_arn" {
  description = "The ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2.arn
}

output "iam_instance_profile_name" {
  description = "The name of the IAM instance profile"
  value       = aws_iam_instance_profile.ec2.name
}

output "launch_template_id" {
  description = "The ID of the launch template"
  value       = aws_launch_template.main.id
}

output "launch_template_latest_version" {
  description = "The latest version of the launch template"
  value       = aws_launch_template.main.latest_version
}

output "autoscaling_group_name" {
  description = "The name of the Auto Scaling Group (if created)"
  value       = try(aws_autoscaling_group.main[0].name, null)
}

output "key_pair_name" {
  description = "The name of the key pair (if created)"
  value       = try(aws_key_pair.ec2[0].key_name, null)
}
