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
  description = "VPC ID for the ECS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ECS tasks (use private subnets)"
  type        = list(string)
}

variable "use_fargate" {
  description = "Use Fargate instead of EC2 launch type"
  type        = bool
  default     = true
}

variable "use_fargate_spot" {
  description = "Use FARGATE_SPOT for cost savings (may be interrupted)"
  type        = bool
  default     = false
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "task_cpu" {
  description = "Task-level CPU units (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Task-level memory in MB"
  type        = string
  default     = "512"
}

variable "container_name" {
  description = "Name of the main container"
  type        = string
}

variable "container_image" {
  description = "Docker image for the container (e.g., nginx:latest or ECR URI)"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 80
}

variable "container_cpu" {
  description = "Container CPU units"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Container memory in MB"
  type        = number
  default     = 512
}

variable "container_environment" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "container_secrets" {
  description = "Secrets for the container (name -> ARN in Secrets Manager or SSM)"
  type        = map(string)
  default     = {}
}

variable "desired_count" {
  description = "Desired number of running tasks"
  type        = number
  default     = 2
}

variable "assign_public_ip" {
  description = "Assign public IP to Fargate tasks"
  type        = bool
  default     = false
}

variable "target_group_arn" {
  description = "ALB target group ARN to register tasks with (leave empty to skip)"
  type        = string
  default     = ""
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for debugging running tasks"
  type        = bool
  default     = false
}

variable "task_ingress_rules" {
  description = "Ingress rules for ECS task security group"
  type = list(object({
    from_port                = number
    to_port                  = number
    protocol                 = string
    source_security_group_ids = optional(list(string), null)
    cidr_blocks              = optional(list(string), null)
  }))
  default = []
}

variable "task_custom_policy" {
  description = "Custom IAM policy JSON for the task role"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
}

variable "enable_autoscaling" {
  description = "Enable auto scaling for the ECS service"
  type        = bool
  default     = true
}

variable "autoscaling_min_capacity" {
  description = "Minimum number of tasks"
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of tasks"
  type        = number
  default     = 10
}

variable "autoscaling_cpu_target" {
  description = "Target CPU utilization % for auto scaling"
  type        = number
  default     = 70
}

variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}
