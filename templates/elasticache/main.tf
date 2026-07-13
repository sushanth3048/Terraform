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

# Security Group for ElastiCache
resource "aws_security_group" "elasticache" {
  name        = "${var.project}-${var.environment}-elasticache-sg"
  description = "Security group for ElastiCache cluster"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.engine == "redis" ? 6379 : 11211
    to_port         = var.engine == "redis" ? 6379 : 11211
    protocol        = "tcp"
    cidr_blocks     = var.allowed_cidr_blocks
    security_groups = var.allowed_security_group_ids
    description     = "${var.engine} access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-elasticache-sg" })
}

# Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-cache-subnet-group"
  subnet_ids = var.subnet_ids

  tags = var.tags
}

# Parameter Group
resource "aws_elasticache_parameter_group" "main" {
  name   = "${var.project}-${var.environment}-cache-params"
  family = var.parameter_group_family

  dynamic "parameter" {
    for_each = var.cache_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = var.tags
}

# Redis Replication Group (for Redis with replication/cluster mode)
resource "aws_elasticache_replication_group" "redis" {
  count = var.engine == "redis" ? 1 : 0

  replication_group_id = "${var.project}-${var.environment}-redis"
  description          = "${var.project} ${var.environment} Redis cluster"

  node_type            = var.node_type
  num_cache_clusters   = var.cluster_mode_enabled ? null : var.num_cache_nodes
  port                 = 6379

  parameter_group_name = aws_elasticache_parameter_group.main.name
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.elasticache.id]

  engine_version       = var.engine_version
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token           = var.auth_token != "" ? var.auth_token : null

  automatic_failover_enabled = var.num_cache_nodes > 1 || var.cluster_mode_enabled
  multi_az_enabled           = var.multi_az_enabled

  dynamic "num_node_groups" {
    for_each = var.cluster_mode_enabled ? [1] : []
    content {}
  }

  num_node_groups         = var.cluster_mode_enabled ? var.num_node_groups : null
  replicas_per_node_group = var.cluster_mode_enabled ? var.replicas_per_node_group : null

  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window
  maintenance_window       = var.maintenance_window

  auto_minor_version_upgrade = true
  apply_immediately          = var.apply_immediately

  tags = var.tags
}

# Memcached Cluster
resource "aws_elasticache_cluster" "memcached" {
  count = var.engine == "memcached" ? 1 : 0

  cluster_id           = "${var.project}-${var.environment}-memcached"
  engine               = "memcached"
  node_type            = var.node_type
  num_cache_nodes      = var.num_cache_nodes
  parameter_group_name = aws_elasticache_parameter_group.main.name
  port                 = 11211
  engine_version       = var.engine_version

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache.id]

  maintenance_window = var.maintenance_window
  apply_immediately  = var.apply_immediately

  tags = var.tags
}
