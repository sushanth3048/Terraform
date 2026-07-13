variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "description" {
  description = "Description of the Lambda function"
  type        = string
  default     = ""
}

variable "runtime" {
  description = "Lambda runtime (python3.12, nodejs20.x, java17, go1.x, etc.)"
  type        = string
  default     = "python3.12"
}

variable "handler" {
  description = "Lambda function handler (e.g., index.handler or main.lambda_handler)"
  type        = string
  default     = "index.handler"
}

variable "filename" {
  description = "Path to the deployment package zip (used when s3_bucket is empty)"
  type        = string
  default     = "function.zip"
}

variable "s3_bucket" {
  description = "S3 bucket for deployment package (leave empty to use filename)"
  type        = string
  default     = ""
}

variable "s3_key" {
  description = "S3 key for deployment package (required when s3_bucket is set)"
  type        = string
  default     = ""
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 128
}

variable "architecture" {
  description = "Lambda architecture (x86_64 or arm64)"
  type        = string
  default     = "arm64"
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
}

variable "deploy_in_vpc" {
  description = "Deploy Lambda function inside a VPC"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID (required when deploy_in_vpc = true)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for VPC deployment"
  type        = list(string)
  default     = []
}

variable "custom_policy" {
  description = "Custom IAM policy JSON to attach to the Lambda role"
  type        = string
  default     = ""
}

variable "dead_letter_target_arn" {
  description = "ARN of SQS or SNS for dead letter queue"
  type        = string
  default     = ""
}

variable "enable_xray" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = false
}

variable "reserved_concurrency" {
  description = "Reserved concurrent executions (-1 for unreserved)"
  type        = number
  default     = -1
}

variable "provisioned_concurrency" {
  description = "Number of provisioned concurrency executions (0 to disable)"
  type        = number
  default     = 0
}

variable "create_layer" {
  description = "Create a Lambda layer from a local file"
  type        = bool
  default     = false
}

variable "layer_filename" {
  description = "Path to the layer zip file (required when create_layer = true)"
  type        = string
  default     = ""
}

variable "additional_layer_arns" {
  description = "List of existing Lambda layer ARNs to attach"
  type        = list(string)
  default     = []
}

variable "event_source_mappings" {
  description = "Event source mappings for SQS, DynamoDB Streams, or Kinesis"
  type = map(object({
    event_source_arn  = string
    starting_position = optional(string, null)
    batch_size        = optional(number, 10)
    enabled           = optional(bool, true)
  }))
  default = {}
}

variable "create_function_url" {
  description = "Create a Lambda function URL for direct HTTPS invocation"
  type        = bool
  default     = false
}

variable "function_url_auth_type" {
  description = "Authorization type for function URL (NONE or AWS_IAM)"
  type        = string
  default     = "AWS_IAM"
}

variable "function_url_cors" {
  description = "CORS configuration for function URL"
  type = object({
    allow_origins = list(string)
    allow_methods = list(string)
    allow_headers = list(string)
  })
  default = null
}

variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}
