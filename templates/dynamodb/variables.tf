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

variable "table_name" {
  description = "DynamoDB table name suffix"
  type        = string
}

variable "billing_mode" {
  description = "Billing mode: PAY_PER_REQUEST (on-demand) or PROVISIONED"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "hash_key" {
  description = "Name of the hash (partition) key attribute"
  type        = string
}

variable "range_key" {
  description = "Name of the range (sort) key attribute (leave empty for no sort key)"
  type        = string
  default     = ""
}

variable "attributes" {
  description = "List of attribute definitions (all indexed attributes must be defined)"
  type = list(object({
    name = string
    type = string  # S (String), N (Number), or B (Binary)
  }))
}

variable "read_capacity" {
  description = "Read capacity units (only for PROVISIONED billing mode)"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Write capacity units (only for PROVISIONED billing mode)"
  type        = number
  default     = 5
}

variable "ttl_attribute" {
  description = "Attribute name for TTL (leave empty to disable)"
  type        = string
  default     = ""
}

variable "enable_pitr" {
  description = "Enable Point-in-Time Recovery"
  type        = bool
  default     = true
}

variable "use_custom_kms" {
  description = "Use a custom KMS key instead of AWS-managed key"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption (required when use_custom_kms = true)"
  type        = string
  default     = null
}

variable "enable_streams" {
  description = "Enable DynamoDB Streams"
  type        = bool
  default     = false
}

variable "stream_view_type" {
  description = "Stream view type: KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, or NEW_AND_OLD_IMAGES"
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
}

variable "global_secondary_indexes" {
  description = "List of Global Secondary Index definitions"
  type = list(object({
    name               = string
    hash_key           = string
    range_key          = optional(string, null)
    projection_type    = string  # ALL, KEYS_ONLY, or INCLUDE
    non_key_attributes = optional(list(string), null)
    read_capacity      = optional(number, null)
    write_capacity     = optional(number, null)
  }))
  default = []
}

variable "local_secondary_indexes" {
  description = "List of Local Secondary Index definitions"
  type = list(object({
    name               = string
    range_key          = string
    projection_type    = string
    non_key_attributes = optional(list(string), null)
  }))
  default = []
}

variable "replica_regions" {
  description = "List of regions to replicate the table to (Global Tables)"
  type        = list(string)
  default     = []
}

variable "enable_autoscaling" {
  description = "Enable auto scaling for PROVISIONED billing mode"
  type        = bool
  default     = false
}

variable "autoscaling_read_min" {
  description = "Minimum read capacity for auto scaling"
  type        = number
  default     = 5
}

variable "autoscaling_read_max" {
  description = "Maximum read capacity for auto scaling"
  type        = number
  default     = 100
}

variable "autoscaling_write_min" {
  description = "Minimum write capacity for auto scaling"
  type        = number
  default     = 5
}

variable "autoscaling_write_max" {
  description = "Maximum write capacity for auto scaling"
  type        = number
  default     = 100
}

variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}
