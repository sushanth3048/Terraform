variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "s3_origin_bucket" {
  description = "Name of S3 bucket to use as origin (leave empty for no S3 origin)"
  type        = string
  default     = ""
}

variable "s3_origin_region" {
  description = "Region of the S3 bucket origin"
  type        = string
  default     = "us-east-1"
}

variable "custom_origins" {
  description = "Map of custom (ALB/API) origins"
  type = map(object({
    domain_name     = string
    http_port       = optional(number, 80)
    https_port      = optional(number, 443)
    protocol_policy = optional(string, "https-only")
    custom_headers  = optional(map(string), {})
  }))
  default = {}
}

variable "default_origin_id" {
  description = "Origin ID to use for the default cache behavior"
  type        = string
}

variable "default_root_object" {
  description = "Default root object (e.g., index.html)"
  type        = string
  default     = "index.html"
}

variable "default_allowed_methods" {
  description = "HTTP methods allowed for the default cache behavior"
  type        = list(string)
  default     = ["GET", "HEAD", "OPTIONS"]
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"
}

variable "domain_aliases" {
  description = "List of custom domain aliases (requires ACM certificate)"
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for custom domains (must be in us-east-1)"
  type        = string
  default     = ""
}

variable "waf_web_acl_arn" {
  description = "WAF Web ACL ARN to associate (must be a CLOUDFRONT scope WAF)"
  type        = string
  default     = ""
}

variable "create_custom_cache_policy" {
  description = "Create a custom cache policy instead of using a managed one"
  type        = bool
  default     = false
}

variable "cache_policy_id" {
  description = "Managed cache policy ID (used when create_custom_cache_policy = false)"
  type        = string
  default     = "658327ea-f89d-4fab-a63d-7e88639e58f6"  # CachingOptimized
}

variable "cache_default_ttl" {
  description = "Default TTL in seconds for custom cache policy"
  type        = number
  default     = 86400
}

variable "cache_max_ttl" {
  description = "Maximum TTL in seconds for custom cache policy"
  type        = number
  default     = 31536000
}

variable "cache_query_strings" {
  description = "Include query strings in cache key"
  type        = bool
  default     = false
}

variable "origin_request_policy_id" {
  description = "Managed origin request policy ID"
  type        = string
  default     = ""
}

variable "viewer_request_function_arn" {
  description = "ARN of a CloudFront Function to run on viewer requests"
  type        = string
  default     = ""
}

variable "ordered_cache_behaviors" {
  description = "List of additional cache behaviors for specific path patterns"
  type = list(object({
    path_pattern    = string
    origin_id       = string
    allowed_methods = optional(list(string), ["GET", "HEAD"])
    cache_policy_id = optional(string, "4135ea2d-6df8-44a3-9df3-4b5a84be39ad")
  }))
  default = []
}

variable "geo_restriction_type" {
  description = "Geo restriction type: none, whitelist, or blacklist"
  type        = string
  default     = "none"
}

variable "geo_restriction_locations" {
  description = "List of ISO 3166-1-alpha-2 country codes for geo restriction"
  type        = list(string)
  default     = []
}

variable "enable_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}
