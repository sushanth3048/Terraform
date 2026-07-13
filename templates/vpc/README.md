# VPC Terraform Template

## Overview

This template provisions a production-ready AWS Virtual Private Cloud with a three-tier subnet architecture. It creates and configures the following resources:

- **VPC** with DNS support and DNS hostnames enabled
- **Public subnets** — one per availability zone, with auto-assigned public IPs; routed through an Internet Gateway
- **Private subnets** — one per availability zone; routed through NAT Gateways
- **Database subnets** — isolated tier for RDS, ElastiCache, and other data-layer resources (optional)
- **Internet Gateway (IGW)** — attached to the VPC for public subnet egress/ingress
- **NAT Gateways** — one per AZ by default (configurable to single for cost savings), with Elastic IPs
- **Route tables** — one public route table shared across all public subnets; one private route table per AZ (or one shared when using a single NAT)
- **VPC Flow Logs** — all traffic captured to a CloudWatch Logs group with a dedicated IAM role (optional)

---

## Prerequisites

| Requirement | Version |
|---|---|
| Terraform | `>= 1.3.0` |
| AWS Provider | `~> 5.0` |
| AWS CLI | Configured with credentials (`aws configure`) |

The IAM principal used must have permissions to create VPC resources, IAM roles, and CloudWatch Log Groups.

---

## Quick Start

**1. Create a `terraform.tfvars` file:**

```hcl
aws_region  = "us-east-1"
project     = "myapp"
environment = "prod"

vpc_cidr = "10.0.0.0/16"

availability_zones    = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs  = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
database_subnet_cidrs = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

enable_nat_gateway  = true
single_nat_gateway  = false   # true for dev/staging to save cost

create_database_subnets = true

enable_flow_logs        = true
flow_log_retention_days = 30

tags = {
  Team      = "platform"
  ManagedBy = "terraform"
}
```

**2. Deploy:**

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

---

## Variables Reference

| Variable | Type | Default | Description |
|---|---|---|---|
| `aws_region` | `string` | `"us-east-1"` | AWS region to deploy resources |
| `project` | `string` | *(required)* | Project name used for resource naming |
| `environment` | `string` | *(required)* | Environment name (e.g., `dev`, `staging`, `prod`) |
| `vpc_cidr` | `string` | `"10.0.0.0/16"` | CIDR block for the VPC |
| `public_subnet_cidrs` | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24"]` | CIDR blocks for public subnets; one per AZ |
| `private_subnet_cidrs` | `list(string)` | `["10.0.11.0/24", "10.0.12.0/24"]` | CIDR blocks for private subnets; one per AZ |
| `database_subnet_cidrs` | `list(string)` | `["10.0.21.0/24", "10.0.22.0/24"]` | CIDR blocks for database subnets; one per AZ |
| `availability_zones` | `list(string)` | `["us-east-1a", "us-east-1b"]` | Availability zones; must align with subnet CIDR list lengths |
| `enable_nat_gateway` | `bool` | `true` | Create NAT Gateways for private subnet egress |
| `single_nat_gateway` | `bool` | `false` | Use one shared NAT Gateway instead of one per AZ |
| `create_database_subnets` | `bool` | `true` | Create the dedicated database subnet tier |
| `enable_flow_logs` | `bool` | `true` | Enable VPC Flow Logs to CloudWatch Logs |
| `flow_log_retention_days` | `number` | `30` | CloudWatch log retention period in days |
| `tags` | `map(string)` | `{}` | Tags applied to all resources |

---

## Outputs Reference

| Output | Description |
|---|---|
| `vpc_id` | The ID of the VPC |
| `vpc_cidr` | The CIDR block of the VPC |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs |
| `database_subnet_ids` | List of database subnet IDs |
| `nat_gateway_ids` | List of NAT Gateway IDs |
| `nat_gateway_public_ips` | List of Elastic IPs associated with NAT Gateways |
| `internet_gateway_id` | The ID of the Internet Gateway |
| `public_route_table_id` | The ID of the public route table |
| `private_route_table_ids` | List of private route table IDs (one per AZ, or one if `single_nat_gateway = true`) |

---

## Customization

### Single NAT Gateway (cost savings for non-production)

By default, one NAT Gateway is created per AZ for high availability. For dev or staging environments where availability is less critical, use a single NAT Gateway to cut costs (~$32/month per NAT gateway, plus data transfer):

```hcl
single_nat_gateway = true
```

### Adding a third availability zone

Extend all three subnet CIDR lists and the AZ list simultaneously. The template uses `count` based on list length, so they must stay in sync:

```hcl
availability_zones    = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs  = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
database_subnet_cidrs = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
```

### Disabling Flow Logs for development

Flow Logs incur CloudWatch ingestion and storage costs. Disable them in environments where network visibility is less critical:

```hcl
enable_flow_logs = false
```

### Disabling NAT Gateways entirely

For environments where private instances only need inbound traffic (e.g., internal-only workloads that pull via VPC endpoints), NAT Gateways can be disabled:

```hcl
enable_nat_gateway = false
```

Private subnets will have no default route to the internet. Ensure any required AWS services are accessible via VPC Interface Endpoints.

---

## Remote State

Other templates read VPC outputs from this template's remote state. Configure a backend in each downstream template:

```hcl
# In your other template's main.tf or data.tf
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "my-terraform-state"
    key    = "myapp/prod/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

# Then reference outputs directly:
module "ec2" {
  source  = "../ec2"

  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
}
```
