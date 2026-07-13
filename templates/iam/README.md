# IAM Terraform Template

## Overview

This template manages IAM identities and access policies at scale. It supports any combination of roles, standalone policies, groups, OIDC providers, and service-linked roles through a consistent map-based interface.

**Resources created:**

- **IAM Roles** — with configurable trust policies, session duration, managed policy attachments, inline policies, and optional permissions boundaries
- **Managed Policy Attachments** — attach AWS-managed or customer-managed policies to roles
- **Inline Policies** — embed policy documents directly in a role (useful for unique, non-reusable permissions)
- **Standalone IAM Policies** — customer-managed policies that can be attached to multiple roles, users, or groups
- **IAM Groups** — logical collections of users with shared policy attachments
- **OIDC Identity Providers** — enable GitHub Actions, EKS IRSA, and other federated identities to assume IAM roles without long-lived credentials
- **Service-Linked Roles** — AWS-managed roles required by services such as ECS, RDS, and Auto Scaling

---

## Quick Start

### Lambda Execution Role

```hcl
module "iam" {
  source = "../iam"

  project     = "myapp"
  environment = "prod"
  aws_region  = "us-east-1"

  iam_roles = {
    lambda_processor = {
      description = "Execution role for the order processor Lambda"

      trust_policy_statements = [
        {
          Effect    = "Allow"
          Principal = { Service = "lambda.amazonaws.com" }
          Action    = "sts:AssumeRole"
        }
      ]

      managed_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
        "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
      ]

      inline_policies = {
        dynamodb_access = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect   = "Allow"
              Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
              Resource = "arn:aws:dynamodb:us-east-1:123456789012:table/myapp-prod-orders"
            }
          ]
        })
      }
    }
  }

  tags = {
    Team = "platform"
  }
}
```

### GitHub Actions OIDC Role

```hcl
module "iam" {
  source = "../iam"

  project     = "myapp"
  environment = "prod"

  oidc_providers = {
    github = {
      url            = "https://token.actions.githubusercontent.com"
      client_id_list = ["sts.amazonaws.com"]
      thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
    }
  }

  iam_roles = {
    github_actions_deploy = {
      description = "Role assumed by GitHub Actions for deployments"

      trust_policy_statements = [
        {
          Effect = "Allow"
          Principal = {
            Federated = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            }
            StringLike = {
              "token.actions.githubusercontent.com:sub" = "repo:myorg/myrepo:*"
            }
          }
        }
      ]

      managed_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
      ]
    }
  }

  tags = {
    Purpose = "ci-cd"
  }
}
```

### Standalone Policy

```hcl
module "iam" {
  source = "../iam"

  project     = "myapp"
  environment = "prod"

  iam_policies = {
    s3_read_uploads = {
      description = "Read-only access to the uploads bucket"
      path        = "/myapp/"
      policy_document = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect   = "Allow"
            Action   = ["s3:GetObject", "s3:ListBucket"]
            Resource = [
              "arn:aws:s3:::myapp-prod-uploads",
              "arn:aws:s3:::myapp-prod-uploads/*"
            ]
          }
        ]
      })
    }
  }
}
```

### terraform.tfvars Example

```hcl
project     = "myapp"
environment = "prod"
aws_region  = "us-east-1"

iam_roles = {
  ecs_task = {
    description = "ECS task role for the API service"
    trust_policy_statements = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
    managed_policy_arns = []
    inline_policies = {}
  }
}

tags = {
  Environment = "prod"
  ManagedBy   = "terraform"
}
```

---

## Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `aws_region` | `string` | `"us-east-1"` | AWS region |
| `project` | `string` | — | Project name |
| `environment` | `string` | — | Environment: dev, staging, or prod |
| `iam_roles` | `map(object)` | `{}` | Map of IAM roles to create (see schema below) |
| `iam_policies` | `map(object)` | `{}` | Map of standalone IAM policies to create |
| `iam_groups` | `map(object)` | `{}` | Map of IAM groups to create |
| `oidc_providers` | `map(object)` | `{}` | Map of OIDC identity providers to register |
| `service_linked_roles` | `map(object)` | `{}` | Map of AWS service-linked roles to create |
| `tags` | `map(string)` | `{}` | Tags applied to all resources |

**`iam_roles` object schema:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `description` | `string` | `""` | Human-readable role description |
| `max_session_duration` | `number` | `3600` | Maximum session duration in seconds (3600–43200) |
| `permissions_boundary_arn` | `string` | `null` | ARN of a permissions boundary policy |
| `trust_policy_statements` | `list(any)` | — | IAM policy statements for the trust relationship |
| `managed_policy_arns` | `list(string)` | `[]` | ARNs of managed policies to attach |
| `inline_policies` | `map(string)` | `{}` | Map of inline policy name → JSON policy document |

**`iam_policies` object schema:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `description` | `string` | `""` | Policy description |
| `policy_document` | `string` | — | JSON IAM policy document |
| `path` | `string` | `"/"` | IAM path for the policy |

**`iam_groups` object schema:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `path` | `string` | `"/"` | IAM path for the group |
| `managed_policy_arns` | `list(string)` | `[]` | ARNs of policies to attach to the group |

**`oidc_providers` object schema:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `url` | `string` | — | OIDC provider URL (e.g., `https://token.actions.githubusercontent.com`) |
| `client_id_list` | `list(string)` | — | List of client IDs (audiences) |
| `thumbprint_list` | `list(string)` | — | TLS certificate thumbprints for the provider |

---

## Outputs

| Name | Description |
|------|-------------|
| `role_arns` | Map of role key to ARN |
| `role_names` | Map of role key to full role name |
| `policy_arns` | Map of policy key to ARN |
| `group_names` | Map of group key to full group name |
| `oidc_provider_arns` | Map of OIDC provider key to ARN |

---

## Customization

### GitHub Actions OIDC — Full Setup Guide

OIDC eliminates the need for long-lived AWS access keys in GitHub secrets. GitHub Actions exchanges a short-lived JWT token for temporary AWS credentials.

**Step 1** — Register the GitHub OIDC provider (once per AWS account):

```hcl
oidc_providers = {
  github = {
    url            = "https://token.actions.githubusercontent.com"
    client_id_list = ["sts.amazonaws.com"]
    # GitHub's current thumbprint — verify at https://github.blog/changelog/
    thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  }
}
```

**Step 2** — Create a role with a trust policy scoped to your repository:

```hcl
iam_roles = {
  github_actions = {
    trust_policy_statements = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          # Scope to a specific repo and branch
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:myorg/myrepo:ref:refs/heads/main"
          }
        }
      }
    ]
    managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"]
  }
}
```

**Step 3** — Configure the GitHub Actions workflow:

```yaml
jobs:
  deploy:
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/myapp-prod-github-actions
          aws-region: us-east-1
```

### EKS IRSA (IAM Roles for Service Accounts)

IRSA allows Kubernetes pods to assume IAM roles without node-level credentials.

```hcl
oidc_providers = {
  eks_cluster = {
    url            = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E"
    client_id_list = ["sts.amazonaws.com"]
    thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  }
}

iam_roles = {
  pod_s3_reader = {
    trust_policy_statements = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E:sub" = "system:serviceaccount:default:s3-reader"
            "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
    managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]
  }
}
```

Annotate the Kubernetes service account: `eks.amazonaws.com/role-arn: <role_arn>`.

### Permissions Boundary Usage

Permissions boundaries cap the maximum permissions a role can have, regardless of what policies are attached. They are commonly used in delegated administration scenarios.

```hcl
iam_roles = {
  developer_role = {
    permissions_boundary_arn = "arn:aws:iam::123456789012:policy/DeveloperBoundary"

    trust_policy_statements = [
      {
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::123456789012:root" }
        Action    = "sts:AssumeRole"
      }
    ]

    managed_policy_arns = ["arn:aws:iam::aws:policy/PowerUserAccess"]
  }
}
```

Even with `PowerUserAccess` attached, the role cannot exceed the permissions defined in `DeveloperBoundary`.

### Least-Privilege Policy Writing Tips

1. **Start with AWS CloudTrail** — enable CloudTrail, perform your workflow, then use IAM Access Analyzer to generate a policy from the actual API calls made.

2. **Use resource-level ARNs** — always scope `Resource` to specific ARN patterns rather than `"*"`:
   ```json
   "Resource": "arn:aws:s3:::myapp-prod-uploads/*"
   ```

3. **Separate read and write policies** — create distinct policies for read and write operations so they can be attached independently to different roles.

4. **Add condition keys** — restrict actions by tag, source IP, or MFA status:
   ```json
   "Condition": {
     "StringEquals": { "aws:ResourceTag/Environment": "prod" },
     "Bool": { "aws:MultiFactorAuthPresent": "true" }
   }
   ```

5. **Use IAM Access Analyzer** to validate policies and detect overly permissive statements before deploying.
