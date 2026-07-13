# AWS Terraform Templates

Production-ready Terraform templates for common AWS services. Each template lives in its own folder and is independently deployable.

## Available Templates

| Template | Description | Key Resources |
|----------|-------------|---------------|
| [vpc](./vpc/) | Virtual Private Cloud | VPC, Subnets, NAT Gateways, Flow Logs |
| [ec2](./ec2/) | EC2 Instances / Auto Scaling | Launch Template, ASG, IAM Role, Security Group |
| [s3](./s3/) | S3 Object Storage | Bucket, Versioning, Encryption, Lifecycle Rules |
| [rds](./rds/) | Relational Database (RDS) | PostgreSQL/MySQL, Secrets Manager, Read Replicas |
| [lambda](./lambda/) | Serverless Functions | Lambda, IAM Role, Log Group, Event Sources |
| [alb](./alb/) | Application Load Balancer | ALB, Target Groups, HTTP/HTTPS Listeners |
| [ecs](./ecs/) | Container Orchestration (ECS) | Cluster, Fargate Service, Auto Scaling |
| [dynamodb](./dynamodb/) | NoSQL Database | Table, GSIs, Streams, PITR, Global Tables |
| [elasticache](./elasticache/) | In-Memory Cache | Redis / Memcached Cluster |
| [sns-sqs](./sns-sqs/) | Messaging & Queuing | SNS Topics, SQS Queues, DLQs, Fan-out |
| [cloudfront](./cloudfront/) | CDN & Edge | Distribution, OAC, Cache Policies, WAF |
| [iam](./iam/) | Identity & Access Management | Roles, Policies, OIDC Providers |
| [route53](./route53/) | DNS & Certificates | Hosted Zone, Records, ACM Certificates |

## Getting Started

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.3.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- An AWS account with permissions for the services you want to deploy

### Recommended Deployment Order

Deploy dependent services before the services that use them:

```
1. iam          → Roles and policies needed by other services
2. vpc          → Networking foundation for all VPC-deployed resources
3. s3           → Storage (used by ALB logs, CloudFront, Lambda artifacts)
4. route53      → DNS zone and ACM certificate
5. rds          → Databases (requires VPC private subnets)
6. elasticache  → Cache layer (requires VPC private subnets)
7. dynamodb     → NoSQL tables (no VPC required)
8. sns-sqs      → Messaging layer
9. lambda       → Serverless compute
10. ecs         → Container compute (requires VPC, optionally ALB)
11. ec2         → VM compute (requires VPC)
12. alb         → Load balancer (requires VPC, EC2/ECS targets)
13. cloudfront  → CDN (requires S3 or ALB origin, ACM cert)
```

### Using a Template

Each template is self-contained. To deploy one:

```bash
cd C:\Terraform\AWS\templates\<service>

# 1. Copy the example vars file and fill in your values
copy terraform.tfvars.example terraform.tfvars
# (edit terraform.tfvars)

# 2. Initialize Terraform
terraform init

# 3. Preview changes
terraform plan

# 4. Apply
terraform apply
```

### Sharing State Between Templates

Use [Terraform remote state](https://developer.hashicorp.com/terraform/language/state/remote-state-data) to pass outputs from one template to another.

**Example: VPC outputs consumed by RDS**

In your RDS `main.tf` (or a `data.tf` file):

```hcl
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "my-terraform-state"
    key    = "vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

# Then use:
# data.terraform_remote_state.vpc.outputs.vpc_id
# data.terraform_remote_state.vpc.outputs.private_subnet_ids
```

### Backend Configuration

Add a `backend.tf` file to each template to store state remotely (recommended for team use):

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "<service>/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

## Conventions

- All templates use **consistent variable names**: `project`, `environment`, `aws_region`, `tags`
- Resources are named `<project>-<environment>-<resource>` for easy identification
- Sensitive outputs (passwords, keys) are marked `sensitive = true`
- Encryption at rest is **enabled by default** for all storage services
- IMDSv2 is enforced on all EC2 instances
- Public access is **blocked by default** on S3 buckets

## Customization

See the `README.md` inside each template folder for:
- Full variable reference with types and defaults
- All available outputs
- Common customization patterns and examples

## Security Notes

- Never commit `terraform.tfvars` files containing secrets to version control
- Use `aws_secretsmanager_secret` or SSM Parameter Store for credentials
- Apply the principle of least privilege to all IAM roles
- Enable AWS CloudTrail to audit all API calls
