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

variable "vpc_id" {
  description = "VPC ID for the ALB"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs (use public subnets for internet-facing ALB)"
  type        = list(string)
}

variable "internal" {
  description = "Create an internal ALB (set false for internet-facing)"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the ALB"
  type        = bool
  default     = true
}

variable "idle_timeout" {
  description = "Idle timeout in seconds"
  type        = number
  default     = 60
}

variable "enable_access_logs" {
  description = "Enable access logging to S3"
  type        = bool
  default     = false
}

variable "https_certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener (leave empty for HTTP only)"
  type        = string
  default     = ""
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "default_target_group" {
  description = "Key of the default target group in the target_groups map"
  type        = string
}

variable "target_groups" {
  description = "Map of target groups to create"
  type = map(object({
    port                 = number
    protocol             = string
    target_type          = optional(string, "instance")
    healthy_threshold    = optional(number, 3)
    unhealthy_threshold  = optional(number, 3)
    health_check_interval = optional(number, 30)
    health_check_matcher = optional(string, "200")
    health_check_path    = optional(string, "/health")
    health_check_timeout = optional(number, 5)
    stickiness_enabled   = optional(bool, false)
    cookie_duration      = optional(number, 86400)
  }))
}

variable "listener_rules" {
  description = "Map of listener rules for path/host-based routing"
  type = map(object({
    priority         = number
    target_group_key = string
    path_patterns    = optional(list(string), null)
    host_headers     = optional(list(string), null)
  }))
  default = {}
}

variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}
