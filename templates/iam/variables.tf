variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "iam_roles" {
  description = "Map of IAM roles to create"
  type = map(object({
    description              = optional(string, "")
    max_session_duration     = optional(number, 3600)
    permissions_boundary_arn = optional(string, null)
    trust_policy_statements  = list(any)
    managed_policy_arns      = optional(list(string), [])
    inline_policies          = optional(map(string), {})
  }))
  default = {}
}

variable "iam_policies" {
  description = "Map of standalone IAM policies to create"
  type = map(object({
    description     = optional(string, "")
    policy_document = string
    path            = optional(string, "/")
  }))
  default = {}
}

variable "iam_groups" {
  description = "Map of IAM groups to create"
  type = map(object({
    path                = optional(string, "/")
    managed_policy_arns = optional(list(string), [])
  }))
  default = {}
}

variable "oidc_providers" {
  description = "Map of OIDC identity providers (for GitHub Actions, EKS IRSA, etc.)"
  type = map(object({
    url             = string
    client_id_list  = list(string)
    thumbprint_list = list(string)
  }))
  default = {}
}

variable "service_linked_roles" {
  description = "Map of AWS service-linked roles to create"
  type = map(object({
    service_name  = string
    description   = optional(string, "")
    custom_suffix = optional(string, null)
  }))
  default = {}
}

variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}
