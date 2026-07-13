variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "bucket_name" {
  description = "Explicit bucket name (overrides auto-generated name)"
  type        = string
  default     = ""
}

variable "bucket_suffix" {
  description = "Suffix appended to the auto-generated bucket name for uniqueness"
  type        = string
  default     = "data"
}

variable "force_destroy" {
  description = "Allow bucket to be destroyed even if it contains objects"
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "Enable versioning on the bucket"
  type        = bool
  default     = true
}

variable "use_kms" {
  description = "Use KMS encryption instead of AES256"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "KMS key ARN for bucket encryption (required when use_kms = true)"
  type        = string
  default     = null
}

variable "block_public_access" {
  description = "Block all public access to the bucket"
  type        = bool
  default     = true
}

variable "enable_access_logging" {
  description = "Enable S3 access logging to a separate bucket"
  type        = bool
  default     = false
}

variable "bucket_policy" {
  description = "JSON bucket policy to attach (leave empty for no policy)"
  type        = string
  default     = ""
}

variable "lifecycle_rules" {
  description = "List of lifecycle rules for the bucket"
  type = list(object({
    id     = string
    status = string
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
    expiration = optional(object({
      days = number
    }), null)
    noncurrent_version_transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
    noncurrent_version_expiration = optional(object({
      days = number
    }), null)
  }))
  default = []
}

variable "cors_rules" {
  description = "List of CORS rules for the bucket"
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number, 3000)
  }))
  default = []
}

variable "lambda_notifications" {
  description = "List of Lambda function notifications for bucket events"
  type = list(object({
    lambda_arn    = string
    events        = list(string)
    filter_prefix = optional(string, null)
    filter_suffix = optional(string, null)
  }))
  default = []
}

variable "sqs_notifications" {
  description = "List of SQS queue notifications for bucket events"
  type = list(object({
    queue_arn     = string
    events        = list(string)
    filter_prefix = optional(string, null)
    filter_suffix = optional(string, null)
  }))
  default = []
}

variable "tags" {
  description = "A map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}
