output "role_arns" {
  description = "Map of role name to ARN"
  value       = { for k, r in aws_iam_role.roles : k => r.arn }
}

output "role_names" {
  description = "Map of role key to full role name"
  value       = { for k, r in aws_iam_role.roles : k => r.name }
}

output "policy_arns" {
  description = "Map of policy key to ARN"
  value       = { for k, p in aws_iam_policy.policies : k => p.arn }
}

output "group_names" {
  description = "Map of group key to full group name"
  value       = { for k, g in aws_iam_group.groups : k => g.name }
}

output "oidc_provider_arns" {
  description = "Map of OIDC provider key to ARN"
  value       = { for k, p in aws_iam_openid_connect_provider.main : k => p.arn }
}
