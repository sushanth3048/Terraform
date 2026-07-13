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
  description = "VPC ID for the ElastiCache cluster"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ElastiCache (use private subnets)"
  type        = list(string)
}

variable "engine" {
  description = "Cache engine: redis or memcached"
  type        = string
  default     = "redis"
}

variable "engine_version" {
  description = "Engine version"
  type        = string
  default     = "7.1"
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "num_cache_nodes" {
  description = "Number of cache nodes (for Redis non-cluster mode: number of replicas + 1)"
  type        = number
  default     = 1
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ for automatic failover"
  type        = bool
  default     = false
}

variable "cluster_mode_enabled" {
  description = "Enable Redis cluster mode (sharding)"
  type        = bool
  default     = false
}

variable "num_node_groups" {
  description = "Number of node groups (shards) for cluster mode"
  type        = number
  default     = 1
}

variable "replicas_per_node_group" {
  description = "Number of replicas per shard in cluster mode"
  type        = number
  default     = 1
}

variable "auth_token" {
  description = "Redis AUTH token for transit encryption (leave empty to auto-manage)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "parameter_group_family" {
  description = "Parameter group family (redis7, memcached1.6)"
  type        = string
  default     = "redis7"
}

variable "cache_parameters" {
  description = "List of cache parameters to set"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain snapshots (Redis only)"
  type        = number
  default     = 1
}

variable "snapshot_window" {
  description = "Daily time window for snapshots (UTC)"
  type        = string
  default     = "05:00-06:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window"
  type        = string
  default     = "sun:06:00-sun:07:00"
}

variable "apply_immediately" {
  description = "Apply changes immediately (may cause brief downtime)"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to ElastiCache"
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to connect to ElastiCache"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}
