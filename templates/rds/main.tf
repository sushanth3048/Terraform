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

# Random password for DB (if not provided)
resource "random_password" "db" {
  count   = var.db_password == "" ? 1 : 0
  length  = 16
  special = false
}

# Store password in Secrets Manager
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project}/${var.environment}/rds/password"
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password != "" ? var.db_password : random_password.db[0].result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
  })
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-db-subnet-group" })
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.environment}-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    cidr_blocks     = var.allowed_cidr_blocks
    security_groups = var.allowed_security_group_ids
    description     = "Database access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-rds-sg" })
}

# KMS Key for RDS encryption
resource "aws_kms_key" "rds" {
  count                   = var.encrypt_storage ? 1 : 0
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = var.tags
}

# DB Parameter Group
resource "aws_db_parameter_group" "main" {
  count  = length(var.db_parameters) > 0 ? 1 : 0
  name   = "${var.project}-${var.environment}-${var.engine}-params"
  family = var.parameter_group_family

  dynamic "parameter" {
    for_each = var.db_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", "immediate")
    }
  }

  tags = var.tags
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier     = "${var.project}-${var.environment}-db"
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password != "" ? var.db_password : random_password.db[0].result
  port     = var.db_port

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = length(var.db_parameters) > 0 ? aws_db_parameter_group.main[0].name : null

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.encrypt_storage
  kms_key_id            = var.encrypt_storage ? aws_kms_key.rds[0].arn : null

  multi_az               = var.multi_az
  publicly_accessible    = false
  deletion_protection    = var.deletion_protection
  skip_final_snapshot    = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project}-${var.environment}-final-snapshot"

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null

  enabled_cloudwatch_logs_exports = var.cloudwatch_logs_exports

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-db" })
}

# Read Replica
resource "aws_db_instance" "replica" {
  count              = var.replica_count
  identifier         = "${var.project}-${var.environment}-db-replica-${count.index + 1}"
  replicate_source_db = aws_db_instance.main.identifier
  instance_class     = var.replica_instance_class != "" ? var.replica_instance_class : var.instance_class

  publicly_accessible = false
  skip_final_snapshot = true

  performance_insights_enabled = var.enable_performance_insights

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-db-replica-${count.index + 1}" })
}
