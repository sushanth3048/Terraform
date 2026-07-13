# ECS (Elastic Container Service) Terraform Template

## Overview

This template provisions a production-ready ECS cluster with full support for both Fargate and EC2 launch types. It creates everything needed to run containerized workloads on AWS.

**Resources created:**

- **ECS Cluster** with optional CloudWatch Container Insights
- **Capacity Providers** — FARGATE, FARGATE\_SPOT, or EC2 (configurable)
- **Task Definition** with container definitions, log configuration, and optional secrets injection
- **ECS Service** with configurable desired count and optional ALB integration
- **Application Auto Scaling** — CPU-based target tracking policy
- **Task Execution IAM Role** — permissions for ECR pulls, CloudWatch Logs, and Secrets Manager/SSM access
- **Task IAM Role** — runtime permissions for the application (customizable inline policy)
- **Security Group** — controls inbound access to ECS tasks
- **CloudWatch Log Group** — centralized log collection with configurable retention

---

## Quick Start

### Fargate Service Behind an ALB

```hcl
module "ecs" {
  source = "../ecs"

  project     = "myapp"
  environment = "prod"
  aws_region  = "us-east-1"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  use_fargate      = true
  use_fargate_spot = false

  container_name  = "api"
  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp-api:latest"
  container_port  = 8080

  task_cpu    = "512"
  task_memory = "1024"

  desired_count = 2

  target_group_arn = module.alb.target_group_arn

  container_environment = {
    APP_ENV  = "production"
    LOG_LEVEL = "info"
  }

  container_secrets = {
    DB_PASSWORD = "arn:aws:secretsmanager:us-east-1:123456789012:secret:myapp/db-password"
    API_KEY     = "arn:aws:ssm:us-east-1:123456789012:parameter/myapp/api-key"
  }

  enable_autoscaling       = true
  autoscaling_min_capacity = 2
  autoscaling_max_capacity = 20
  autoscaling_cpu_target   = 70

  task_ingress_rules = [
    {
      from_port                 = 8080
      to_port                   = 8080
      protocol                  = "tcp"
      source_security_group_ids = [module.alb.security_group_id]
    }
  ]

  tags = {
    Team = "platform"
  }
}
```

### terraform.tfvars Example

```hcl
project     = "myapp"
environment = "prod"
aws_region  = "us-east-1"

vpc_id     = "vpc-0abc123def456789"
subnet_ids = ["subnet-0aaa111", "subnet-0bbb222"]

use_fargate = true

container_name  = "api"
container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp-api:v1.2.3"
container_port  = 8080
task_cpu        = "512"
task_memory     = "1024"

desired_count            = 2
enable_autoscaling       = true
autoscaling_min_capacity = 2
autoscaling_max_capacity = 10
autoscaling_cpu_target   = 70

log_retention_days = 30

tags = {
  Environment = "prod"
  Team        = "platform"
}
```

---

## Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `aws_region` | `string` | `"us-east-1"` | AWS region |
| `project` | `string` | — | Project name (used in resource naming) |
| `environment` | `string` | — | Environment: dev, staging, or prod |
| `vpc_id` | `string` | — | VPC ID where ECS tasks will run |
| `subnet_ids` | `list(string)` | — | Subnet IDs for ECS tasks (use private subnets) |
| `use_fargate` | `bool` | `true` | Use Fargate launch type instead of EC2 |
| `use_fargate_spot` | `bool` | `false` | Use FARGATE\_SPOT capacity for cost savings (interruptible) |
| `enable_container_insights` | `bool` | `true` | Enable CloudWatch Container Insights on the cluster |
| `task_cpu` | `string` | `"256"` | Task-level CPU units (256, 512, 1024, 2048, 4096) |
| `task_memory` | `string` | `"512"` | Task-level memory in MB |
| `container_name` | `string` | — | Name of the main container |
| `container_image` | `string` | — | Docker image URI (ECR or public registry) |
| `container_port` | `number` | `80` | Port the container listens on |
| `container_cpu` | `number` | `256` | CPU units allocated to the container |
| `container_memory` | `number` | `512` | Memory (MB) allocated to the container |
| `container_environment` | `map(string)` | `{}` | Plain-text environment variables |
| `container_secrets` | `map(string)` | `{}` | Secrets: map of env var name → Secrets Manager or SSM ARN |
| `desired_count` | `number` | `2` | Desired number of running tasks |
| `assign_public_ip` | `bool` | `false` | Assign public IP to Fargate tasks |
| `target_group_arn` | `string` | `""` | ALB target group ARN (leave empty to skip load balancer) |
| `enable_execute_command` | `bool` | `false` | Enable ECS Exec for interactive debugging |
| `task_ingress_rules` | `list(object)` | `[]` | Ingress rules for the ECS tasks security group |
| `task_custom_policy` | `string` | `""` | Custom inline IAM policy JSON for the task role |
| `log_retention_days` | `number` | `30` | CloudWatch log retention in days |
| `enable_autoscaling` | `bool` | `true` | Enable Application Auto Scaling for the service |
| `autoscaling_min_capacity` | `number` | `1` | Minimum task count for auto scaling |
| `autoscaling_max_capacity` | `number` | `10` | Maximum task count for auto scaling |
| `autoscaling_cpu_target` | `number` | `70` | Target CPU utilization % that triggers scaling |
| `tags` | `map(string)` | `{}` | Tags applied to all resources |

---

## Outputs

| Name | Description |
|------|-------------|
| `cluster_id` | The ID of the ECS cluster |
| `cluster_name` | The name of the ECS cluster |
| `cluster_arn` | The ARN of the ECS cluster |
| `service_id` | The ID of the ECS service |
| `service_name` | The name of the ECS service |
| `task_definition_arn` | The ARN of the active task definition revision |
| `task_execution_role_arn` | ARN of the task execution IAM role |
| `task_role_arn` | ARN of the task IAM role (runtime permissions) |
| `security_group_id` | Security group ID attached to ECS tasks |
| `log_group_name` | CloudWatch log group name for container logs |

---

## Customization

### Switching Between Fargate and EC2

Set `use_fargate = false` to use EC2 container instances. You are responsible for managing the EC2 Auto Scaling Group and registering instances with the cluster.

```hcl
use_fargate = false
```

For Fargate, the cluster manages compute automatically — no EC2 instances to maintain.

### Using Fargate Spot for Cost Savings

Fargate Spot can reduce compute costs by up to 70% by using spare AWS capacity. Tasks may be interrupted with a 2-minute warning.

```hcl
use_fargate      = true
use_fargate_spot = true
```

Recommended for: batch jobs, workers, dev/staging environments. For production APIs, keep `use_fargate_spot = false` or run a mixed strategy.

### Connecting to an ALB

Pass the target group ARN from your ALB module:

```hcl
target_group_arn = module.alb.target_group_arns["api"]

task_ingress_rules = [
  {
    from_port                 = 8080
    to_port                   = 8080
    protocol                  = "tcp"
    source_security_group_ids = [module.alb.security_group_id]
  }
]
```

The ECS service will register each task with the target group on startup and deregister on shutdown.

### Enabling ECS Exec for Debugging

ECS Exec lets you open an interactive shell into a running container without SSH or bastion hosts.

```hcl
enable_execute_command = true
```

After enabling, connect to a task:

```bash
aws ecs execute-command \
  --cluster myapp-prod \
  --task <task-id> \
  --container api \
  --interactive \
  --command "/bin/sh"
```

The task execution role automatically receives the necessary SSM permissions when this is enabled.

### Injecting Secrets from Secrets Manager and SSM

Use `container_secrets` to pass secrets as environment variables without hardcoding values:

```hcl
container_secrets = {
  # From AWS Secrets Manager
  DB_PASSWORD = "arn:aws:secretsmanager:us-east-1:123456789012:secret:myapp/db-prod-AbCdEf"

  # From SSM Parameter Store
  STRIPE_SECRET_KEY = "arn:aws:ssm:us-east-1:123456789012:parameter/myapp/stripe-secret"
}
```

Secrets are injected at task startup. The task execution role is automatically granted `secretsmanager:GetSecretValue` and `ssm:GetParameters` for the provided ARNs.

### Custom Task Role Permissions

Grant the application additional AWS permissions via `task_custom_policy`:

```hcl
task_custom_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "arn:aws:s3:::myapp-uploads/*"
    },
    {
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem", "dynamodb:PutItem"]
      Resource = "arn:aws:dynamodb:us-east-1:123456789012:table/myapp-sessions"
    }
  ]
})
```
