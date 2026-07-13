terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ──────────────────────────────────────────────
# IAM Roles
# ──────────────────────────────────────────────
resource "aws_iam_role" "roles" {
  for_each = var.iam_roles

  name                 = "${var.project}-${var.environment}-${each.key}"
  description          = lookup(each.value, "description", "")
  max_session_duration = lookup(each.value, "max_session_duration", 3600)

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = each.value.trust_policy_statements
  })

  permissions_boundary = lookup(each.value, "permissions_boundary_arn", null)

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-${each.key}" })
}

# Attach managed policies to roles
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = {
    for item in flatten([
      for role_name, role in var.iam_roles : [
        for policy_arn in lookup(role, "managed_policy_arns", []) : {
          role_key   = role_name
          policy_arn = policy_arn
          key        = "${role_name}-${replace(policy_arn, "/", "-")}"
        }
      ]
    ]) : item.key => item
  }

  role       = aws_iam_role.roles[each.value.role_key].name
  policy_arn = each.value.policy_arn
}

# Inline policies for roles
resource "aws_iam_role_policy" "inline" {
  for_each = {
    for item in flatten([
      for role_name, role in var.iam_roles : [
        for policy_name, policy_doc in lookup(role, "inline_policies", {}) : {
          role_key    = role_name
          policy_name = policy_name
          policy_doc  = policy_doc
          key         = "${role_name}-${policy_name}"
        }
      ]
    ]) : item.key => item
  }

  name   = each.value.policy_name
  role   = aws_iam_role.roles[each.value.role_key].id
  policy = each.value.policy_doc
}

# ──────────────────────────────────────────────
# IAM Policies (standalone managed)
# ──────────────────────────────────────────────
resource "aws_iam_policy" "policies" {
  for_each = var.iam_policies

  name        = "${var.project}-${var.environment}-${each.key}"
  description = lookup(each.value, "description", "")
  policy      = each.value.policy_document
  path        = lookup(each.value, "path", "/")

  tags = var.tags
}

# ──────────────────────────────────────────────
# IAM Groups
# ──────────────────────────────────────────────
resource "aws_iam_group" "groups" {
  for_each = var.iam_groups

  name = "${var.project}-${var.environment}-${each.key}"
  path = lookup(each.value, "path", "/")
}

resource "aws_iam_group_policy_attachment" "group_policies" {
  for_each = {
    for item in flatten([
      for group_name, group in var.iam_groups : [
        for policy_arn in lookup(group, "managed_policy_arns", []) : {
          group_key  = group_name
          policy_arn = policy_arn
          key        = "${group_name}-${replace(policy_arn, "/", "-")}"
        }
      ]
    ]) : item.key => item
  }

  group      = aws_iam_group.groups[each.value.group_key].name
  policy_arn = each.value.policy_arn
}

# ──────────────────────────────────────────────
# OIDC Identity Providers (for GitHub Actions / EKS IRSA)
# ──────────────────────────────────────────────
resource "aws_iam_openid_connect_provider" "main" {
  for_each = var.oidc_providers

  url             = each.value.url
  client_id_list  = each.value.client_id_list
  thumbprint_list = each.value.thumbprint_list

  tags = var.tags
}

# ──────────────────────────────────────────────
# Service-Linked Roles
# ──────────────────────────────────────────────
resource "aws_iam_service_linked_role" "main" {
  for_each = var.service_linked_roles

  aws_service_name = each.value.service_name
  description      = lookup(each.value, "description", "")
  custom_suffix    = lookup(each.value, "custom_suffix", null)
}
