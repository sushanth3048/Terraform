# EC2 Terraform Template

## Overview

This template provisions EC2 compute resources with security and operational best practices built in. It creates and configures the following resources:

- **Security Group** — with configurable ingress rules and unrestricted egress; applied to all instances
- **IAM Role and Instance Profile** — attached to all instances with the `AmazonSSMManagedInstanceCore` policy for SSM Session Manager access (no SSH required)
- **Launch Template** — defines the AMI, instance type, EBS volumes, network settings, IMDSv2 enforcement, and optional user data; supports both standalone instances and ASGs
- **EC2 Instances** — one or more standalone instances when `use_autoscaling = false`
- **Auto Scaling Group** — created instead of standalone instances when `use_autoscaling = true`; uses the launch template and supports EC2 or ELB health checks
- **KMS Key** — customer-managed key for EBS volume encryption (created when `encrypt_ebs = true`)
- **Key Pair** — optional SSH key pair (when `create_key_pair = true`); prefer SSM Session Manager over SSH

The AMI defaults to the latest Amazon Linux 2023 (x86_64 HVM) and is resolved automatically at apply time. A custom AMI can be specified to override this.

---

## Prerequisites

| Requirement | Version |
|---|---|
| Terraform | `>= 1.3.0` |
| AWS Provider | `~> 5.0` |
| AWS CLI | Configured with credentials (`aws configure`) |

A VPC and subnets must exist before deploying this template. Use the [VPC template](../vpc) or reference existing infrastructure via remote state.

---

## Quick Start

**Standalone instance `terraform.tfvars`:**

```hcl
aws_region  = "us-east-1"
project     = "myapp"
environment = "prod"

vpc_id     = "vpc-0abc123def456"
subnet_ids = ["subnet-0aaa111", "subnet-0bbb222"]

instance_type  = "t3.small"
instance_count = 2

root_volume_size = 30
root_volume_type = "gp3"
encrypt_ebs      = true

use_autoscaling = false

ingress_rules = [
  {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }
]

tags = {
  Team      = "platform"
  ManagedBy = "terraform"
}
```

**Auto Scaling Group `terraform.tfvars`:**

```hcl
aws_region  = "us-east-1"
project     = "myapp"
environment = "prod"

vpc_id     = "vpc-0abc123def456"
subnet_ids = ["subnet-0aaa111", "subnet-0bbb222", "subnet-0ccc333"]

instance_type = "t3.medium"
encrypt_ebs   = true

use_autoscaling       = true
asg_desired_capacity  = 2
asg_min_size          = 1
asg_max_size          = 6
asg_health_check_type = "ELB"

tags = {
  Team      = "platform"
  ManagedBy = "terraform"
}
```

**Deploy:**

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
| `vpc_id` | `string` | *(required)* | VPC ID where EC2 instances will be deployed |
| `subnet_ids` | `list(string)` | *(required)* | Subnet IDs for instance placement; use private subnets for non-public workloads |
| `instance_type` | `string` | `"t3.micro"` | EC2 instance type |
| `ami_id` | `string` | `""` | Custom AMI ID; leave empty to use the latest Amazon Linux 2023 |
| `instance_count` | `number` | `1` | Number of standalone instances (only used when `use_autoscaling = false`) |
| `associate_public_ip` | `bool` | `false` | Assign a public IP to instances |
| `root_volume_size` | `number` | `20` | Root EBS volume size in GB |
| `root_volume_type` | `string` | `"gp3"` | Root EBS volume type (`gp3`, `gp2`, `io1`, `io2`) |
| `encrypt_ebs` | `bool` | `true` | Encrypt EBS volumes with a KMS customer-managed key |
| `create_key_pair` | `bool` | `false` | Create a new EC2 key pair for SSH access |
| `public_key` | `string` | `""` | Public key material for the key pair (required when `create_key_pair = true`) |
| `existing_key_name` | `string` | `null` | Name of an existing key pair to attach to instances |
| `user_data` | `string` | `""` | Shell script to run on first boot (plain text; base64-encoded automatically) |
| `enable_detailed_monitoring` | `bool` | `false` | Enable 1-minute CloudWatch metric resolution (standard is 5-minute) |
| `ingress_rules` | `list(object)` | HTTPS from `0.0.0.0/0` | Security group ingress rules; each object requires `from_port`, `to_port`, `protocol`, `cidr_blocks`, `description` |
| `use_autoscaling` | `bool` | `false` | Create an Auto Scaling Group instead of standalone instances |
| `asg_desired_capacity` | `number` | `2` | Desired instance count in the ASG |
| `asg_min_size` | `number` | `1` | Minimum instance count in the ASG |
| `asg_max_size` | `number` | `4` | Maximum instance count in the ASG |
| `asg_health_check_type` | `string` | `"EC2"` | ASG health check type (`EC2` or `ELB`) |
| `tags` | `map(string)` | `{}` | Tags applied to all resources |

---

## Outputs Reference

| Output | Description |
|---|---|
| `instance_ids` | List of EC2 instance IDs (standalone instances only) |
| `instance_private_ips` | List of private IP addresses (standalone instances only) |
| `instance_public_ips` | List of public IP addresses (standalone instances only; empty if `associate_public_ip = false`) |
| `security_group_id` | ID of the EC2 security group |
| `iam_role_arn` | ARN of the EC2 IAM role |
| `iam_instance_profile_name` | Name of the IAM instance profile |
| `launch_template_id` | ID of the launch template |
| `launch_template_latest_version` | Latest version number of the launch template |
| `autoscaling_group_name` | Name of the Auto Scaling Group (null when `use_autoscaling = false`) |
| `key_pair_name` | Name of the created key pair (null when `create_key_pair = false`) |

---

## Customization

### Using a custom AMI

Set `ami_id` to any valid AMI ID in your target region to bypass the Amazon Linux 2023 data source lookup:

```hcl
ami_id = "ami-0c55b159cbfafe1f0"
```

Useful for golden AMIs, marketplace images, or Windows instances.

### Adding a user data script

Pass a shell script as a string. The template automatically base64-encodes it:

```hcl
user_data = <<-EOF
  #!/bin/bash
  yum update -y
  yum install -y amazon-cloudwatch-agent
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -s -c ssm:/cloudwatch-config
EOF
```

For larger scripts, use `file()`:

```hcl
user_data = file("${path.module}/scripts/bootstrap.sh")
```

### Switching between standalone instances and ASG

Toggle `use_autoscaling`:

```hcl
# Standalone
use_autoscaling = false
instance_count  = 2

# Auto Scaling Group
use_autoscaling      = true
asg_desired_capacity = 2
asg_min_size         = 1
asg_max_size         = 6
```

Note: when using an ASG behind an ALB, set `asg_health_check_type = "ELB"` so the ASG replaces instances that the load balancer marks unhealthy.

### Adding SSH access

> **Security note:** SSH access is not recommended. All instances have SSM Session Manager access through the attached IAM role, which provides shell access without opening port 22 or managing key pairs. Use `aws ssm start-session --target <instance-id>` or the AWS Console instead.

If SSH is required, add an ingress rule and attach a key pair:

```hcl
create_key_pair = true
public_key      = file("~/.ssh/id_rsa.pub")

ingress_rules = [
  {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]   # restrict to internal CIDR only
    description = "SSH from internal network"
  }
]
```

Restrict `cidr_blocks` to the narrowest possible range and never use `0.0.0.0/0` for port 22.

---

## Security Best Practices

### IMDSv2 enforcement

The launch template sets `http_tokens = "required"`, which means all requests to the EC2 metadata service (169.254.169.254) must use the session-oriented IMDSv2 protocol. This prevents SSRF-based credential theft attacks that were possible with IMDSv1.

### EBS encryption

When `encrypt_ebs = true` (the default), a customer-managed KMS key is created with automatic key rotation enabled. All root volumes are encrypted at rest. This satisfies most regulatory compliance requirements (SOC 2, PCI-DSS, HIPAA) for data at rest.

### SSM Session Manager over SSH

The `AmazonSSMManagedInstanceCore` policy is always attached to the IAM role. This enables:

- Shell access via SSM without port 22 open
- Session logging to CloudWatch or S3 for audit trails
- Port forwarding for debugging without a bastion host
- Works from the AWS Console, CLI (`aws ssm start-session`), and the SSM plugin for SSH/SCP

To connect: `aws ssm start-session --target i-0abc1234def56789`
