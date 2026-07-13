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

variable "domain_name" {
  description = "The domain name for the hosted zone or existing zone to look up"
  type        = string
}

variable "create_zone" {
  description = "Create a new hosted zone (false to use an existing zone)"
  type        = bool
  default     = true
}

variable "private_zone" {
  description = "Create a private hosted zone (requires vpc_ids)"
  type        = bool
  default     = false
}

variable "private_zone_vpc_ids" {
  description = "VPC IDs to associate with the private hosted zone"
  type        = list(string)
  default     = []
}

variable "records" {
  description = "Map of DNS records to create"
  type = map(object({
    name            = string
    type            = string
    ttl             = optional(number, 300)
    records         = optional(list(string), null)
    alias           = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = optional(bool, true)
    }), null)
    weight          = optional(number, null)
    failover        = optional(string, null)
    set_identifier  = optional(string, null)
    health_check_key = optional(string, null)
  }))
  default = {}
}

variable "health_checks" {
  description = "Map of Route53 health checks to create"
  type = map(object({
    type              = string
    fqdn              = optional(string, null)
    ip_address        = optional(string, null)
    port              = optional(number, 443)
    resource_path     = optional(string, "/")
    failure_threshold = optional(number, 3)
    request_interval  = optional(number, 30)
    enable_sni        = optional(bool, true)
  }))
  default = {}
}

variable "create_acm_certificate" {
  description = "Create an ACM certificate with DNS validation for the domain"
  type        = bool
  default     = false
}

variable "certificate_san" {
  description = "Subject Alternative Names for the ACM certificate"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}
