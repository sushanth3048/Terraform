# RDS Terraform Template

Provisions a production-ready Amazon RDS instance with supporting infrastructure including a DB subnet group, security group, optional KMS encryption key, DB parameter group, and Secrets Manager credential storage. Supports any RDS engine (PostgreSQL, MySQL, MariaDB, Oracle, SQL Server) with optional read replicas.

## Resources Created

| Resource | Description |
|---|---|
| `aws_db_subnet_group` | DB subnet group spanning the provided subnets |
| `aws_security_group` | Security group controlling inbound database access |
| `aws_kms_key` | Customer-managed KMS key for storage encryption (when `encrypt_storage = true`) |
| `aws_db_parameter_group` | Parameter group for engine-level configuration |
| `aws_db_instance` (primary) | The RDS database instance |
| `aws_secretsmanager_secret` | Stores the master credentials (username + password) as JSON |
| `aws_db_instance` (replicas) | One or more read replicas (when `replica_count > 0`) |

## Prerequisites

- Terraform >= 1.3
- AWS provider >= 5.0
- An existing VPC with **private** subnets in at least two Availability Zones
- IAM permissions to create RDS, KMS, Secrets Manager, and EC2 security group resources

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

### Example: PostgreSQL (default)

```hcl
# terraform.tfvars

aws_region  = "us-east-1"
project     = "myapp"
environment = "prod"

vpc_id     = "vpc-0abc123456789def0"
subnet_ids = ["subnet-0aaa111111111111a", "subnet-0bbb222222222222b", "subnet-0ccc333333333333c"]

engine          = "postgres"
engine_version  = "15.4"
instance_class  = "db.t3.medium"
db_name         = "myappdb"
db_username     = "myappuser"
db_password     = ""   # leave empty for auto-generated password

allocated_storage     = 50
max_allocated_storage = 200
storage_type          = "gp3"

multi_az                = true
deletion_protection     = true
skip_final_snapshot     = false
backup_retention_period = 14
backup_window           = "03:00-04:00"
maintenance_window      = "Mon:04:00-Mon:05:00"

encrypt_storage             = true
enable_performance_insights = true
cloudwatch_logs_exports     = ["postgresql", "upgrade"]

parameter_group_family = "postgres15"
db_parameters = [
  { name = "log_min_duration_statement", value = "1000" },
  { name = "log_connections",            value = "1"    }
]

allowed_security_group_ids = ["sg-0app111111111111a"]

tags = {
  Team        = "platform"
  CostCenter  = "engineering"
}
```

### Example: MySQL

```hcl
# terraform.tfvars

aws_region  = "us-east-1"
project     = "myapp"
environment = "staging"

vpc_id     = "vpc-0abc123456789def0"
subnet_ids = ["subnet-0aaa111111111111a", "subnet-0bbb222222222222b"]

engine         = "mysql"
engine_version = "8.0"
instance_class = "db.t3.small"
db_name        = "myappdb"
db_username    = "admin"
db_password    = ""   # leave empty for auto-generated password
db_port        = 3306

allocated_storage     = 20
max_allocated_storage = 100
storage_type          = "gp3"

multi_az                = false
deletion_protection     = false
skip_final_snapshot     = true
backup_retention_period = 7

encrypt_storage             = true
enable_performance_insights = false
cloudwatch_logs_exports     = ["error", "slowquery", "general"]

parameter_group_family = "mysql8.0"
db_parameters = [
  { name = "slow_query_log",   value = "1"    },
  { name = "long_query_time",  value = "2"    },
  { name = "max_connections",  value = "200", apply_method = "pending-reboot" }
]

allowed_cidr_blocks = ["10.0.0.0/8"]

tags = {
  Environment = "staging"
}
```

---

## Variables Reference

| Variable | Type | Default | Description |
|---|---|---|---|
| `aws_region` | `string` | `"us-east-1"` | AWS region to deploy into |
| `project` | `string` | — | Project name (used in resource naming) |
| `environment` | `string` | — | Environment name: `dev`, `staging`, or `prod` |
| `vpc_id` | `string` | — | ID of the VPC where the instance will be deployed |
| `subnet_ids` | `list(string)` | — | Private subnet IDs for the DB subnet group (minimum 2, in different AZs) |
| `engine` | `string` | `"postgres"` | Database engine: `postgres`, `mysql`, `mariadb`, `oracle-ee`, `sqlserver-ex` |
| `engine_version` | `string` | `"15.4"` | Engine version string (must match the chosen engine) |
| `instance_class` | `string` | `"db.t3.micro"` | RDS instance type (e.g., `db.t3.medium`, `db.r6g.large`) |
| `db_name` | `string` | — | Name of the initial database to create |
| `db_username` | `string` | `"dbadmin"` | Master username for the database |
| `db_password` | `string` | `""` | Master password. Leave empty to auto-generate a secure password |
| `db_port` | `number` | `5432` | Port the database listens on (e.g., `3306` for MySQL) |
| `allocated_storage` | `number` | `20` | Initial storage allocation in GB |
| `max_allocated_storage` | `number` | `100` | Maximum storage ceiling for autoscaling in GB. Set `0` to disable autoscaling |
| `storage_type` | `string` | `"gp3"` | EBS storage type: `gp3` (recommended), `gp2`, or `io1` |
| `encrypt_storage` | `bool` | `true` | Enable storage encryption with a customer-managed KMS key |
| `multi_az` | `bool` | `false` | Deploy a standby replica in a second AZ for automatic failover |
| `deletion_protection` | `bool` | `true` | Prevent the instance from being deleted via the API |
| `skip_final_snapshot` | `bool` | `false` | Skip final snapshot on destroy. Set `true` only for ephemeral environments |
| `backup_retention_period` | `number` | `7` | Days to retain automated backups (0–35). Set `0` to disable backups |
| `backup_window` | `string` | `"03:00-04:00"` | Daily UTC window for automated backups (format: `hh:mm-hh:mm`) |
| `maintenance_window` | `string` | `"Mon:04:00-Mon:05:00"` | Weekly UTC window for maintenance (format: `Ddd:hh:mm-Ddd:hh:mm`) |
| `enable_performance_insights` | `bool` | `true` | Enable RDS Performance Insights (not available on all instance classes) |
| `cloudwatch_logs_exports` | `list(string)` | `["postgresql"]` | Log types to export to CloudWatch Logs |
| `auto_minor_version_upgrade` | `bool` | `true` | Automatically apply minor engine version upgrades during the maintenance window |
| `apply_immediately` | `bool` | `false` | Apply modifications immediately rather than at the next maintenance window |
| `allowed_cidr_blocks` | `list(string)` | `[]` | CIDR ranges allowed to reach the database port |
| `allowed_security_group_ids` | `list(string)` | `[]` | Security group IDs (e.g., app server SGs) allowed to reach the database port |
| `parameter_group_family` | `string` | `"postgres15"` | DB parameter group family (must match engine and version) |
| `db_parameters` | `list(object)` | `[]` | List of engine parameters to set. Each object has `name`, `value`, and optional `apply_method` (`"immediate"` or `"pending-reboot"`) |
| `replica_count` | `number` | `0` | Number of read replicas to create |
| `replica_instance_class` | `string` | `""` | Instance class for read replicas. Defaults to the primary `instance_class` when left empty |
| `tags` | `map(string)` | `{}` | Additional tags applied to all resources |

---

## Outputs Reference

| Output | Description |
|---|---|
| `db_instance_id` | The RDS instance identifier |
| `db_instance_arn` | The ARN of the RDS instance |
| `db_endpoint` | Connection endpoint in `host:port` format |
| `db_address` | Hostname of the RDS instance (without port) |
| `db_port` | Port the database is listening on |
| `db_name` | Name of the initial database |
| `security_group_id` | ID of the security group attached to the RDS instance |
| `db_subnet_group_name` | Name of the DB subnet group |
| `secrets_manager_secret_arn` | ARN of the Secrets Manager secret holding the master credentials |
| `replica_endpoints` | List of read replica endpoints (`host:port`) |

---

## Customization

### Retrieving Credentials from Secrets Manager

The master username and password are stored as a JSON object in AWS Secrets Manager. Retrieve them at runtime without embedding credentials in your application configuration:

```bash
# Retrieve the full secret JSON
aws secretsmanager get-secret-value \
  --secret-id "$(terraform output -raw secrets_manager_secret_arn)" \
  --query SecretString \
  --output text

# Output example:
# {"username":"myappuser","password":"s0m3G3n3r@tedP@ssw0rd"}
```

In application code, fetch the secret using the AWS SDK and parse the JSON to extract `username` and `password`.

### Adding Read Replicas

Set `replica_count` to the desired number of replicas. Replicas are deployed in different AZs automatically:

```hcl
replica_count          = 2
replica_instance_class = "db.t3.small"   # optional, defaults to primary class
```

Access replica endpoints via the `replica_endpoints` output:

```bash
terraform output replica_endpoints
```

### Configuring Custom DB Parameters

Pass a list of parameter objects. Use `apply_method = "pending-reboot"` for parameters that require a restart:

```hcl
db_parameters = [
  { name = "work_mem",               value = "65536"  },
  { name = "shared_buffers",         value = "131072", apply_method = "pending-reboot" },
  { name = "log_min_duration_statement", value = "500" }
]
```

### Engine-Specific `parameter_group_family` Values

| Engine | Version | `parameter_group_family` |
|---|---|---|
| PostgreSQL | 15.x | `postgres15` |
| PostgreSQL | 14.x | `postgres14` |
| PostgreSQL | 13.x | `postgres13` |
| MySQL | 8.0.x | `mysql8.0` |
| MySQL | 5.7.x | `mysql5.7` |
| MariaDB | 10.6.x | `mariadb10.6` |
| Oracle EE | 19.x | `oracle-ee-19` |
| SQL Server EX | 15.x | `sqlserver-ex-15.0` |

### CloudWatch Logs Exports by Engine

| Engine | Valid log types |
|---|---|
| PostgreSQL | `postgresql`, `upgrade` |
| MySQL | `audit`, `error`, `general`, `slowquery` |
| MariaDB | `audit`, `error`, `general`, `slowquery` |
| Oracle | `alert`, `audit`, `listener`, `trace` |
| SQL Server | `agent`, `error` |

---

## Security Considerations

- **Never hardcode passwords.** Leave `db_password = ""` to have Terraform generate a strong random password, which is then stored in Secrets Manager. The plaintext password is never written to state in a recoverable form.
- **Use private subnets only.** Always provide private subnet IDs in `subnet_ids`. The security group created by this template has no default inbound rules — access must be explicitly granted via `allowed_cidr_blocks` or `allowed_security_group_ids`.
- **Prefer security group references over CIDR blocks.** Using `allowed_security_group_ids` scopes access to specific workloads (e.g., your application's security group) and avoids broad IP-range allowances.
- **Enable encryption.** `encrypt_storage = true` is the default and uses a dedicated customer-managed KMS key, allowing you to audit and revoke access at the key level.
- **Enable deletion protection in production.** `deletion_protection = true` (the default) prevents accidental `terraform destroy` from dropping the database.
- **Set `skip_final_snapshot = false` in production.** The default ensures a final snapshot is taken before any deletion, providing a last-resort recovery point.
