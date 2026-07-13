# S3 Terraform Template

## Overview

This template provisions a secure, production-ready S3 bucket with a consistent set of baseline controls applied by default. It creates and configures the following resources:

- **S3 Bucket** — named either explicitly via `bucket_name` or auto-generated as `{project}-{environment}-{bucket_suffix}`
- **Versioning** — enabled by default; all object versions are preserved and recoverable
- **Server-Side Encryption (SSE)** — AES256 (SSE-S3) by default; switchable to SSE-KMS with a customer-managed key
- **Public Access Block** — all four public access block settings are enabled by default, preventing any public exposure
- **Lifecycle Rules** — configurable transitions (Standard → IA → Glacier) and expirations for both current and noncurrent versions
- **CORS Configuration** — optional; configurable per-origin rules for browser-based access
- **Bucket Policy** — optional; accepts any valid IAM policy JSON string
- **Access Logging** — optional; creates a separate logging bucket and streams access logs to it
- **Event Notifications** — optional Lambda function and SQS queue notification targets with prefix/suffix filters

---

## Prerequisites

| Requirement | Version |
|---|---|
| Terraform | `>= 1.3.0` |
| AWS Provider | `~> 5.0` |
| AWS CLI | Configured with credentials (`aws configure`) |

S3 bucket names are globally unique. The auto-generated name (`{project}-{environment}-{bucket_suffix}`) will fail if it is already taken by another AWS account. Use `bucket_name` to specify an explicit name if needed.

---

## Quick Start

**Simple bucket `terraform.tfvars`:**

```hcl
aws_region  = "us-east-1"
project     = "myapp"
environment = "prod"
bucket_suffix = "assets"

enable_versioning   = true
block_public_access = true
encrypt_ebs         = false   # uses AES256 by default

tags = {
  Team      = "platform"
  ManagedBy = "terraform"
}
```

**Bucket with lifecycle rules `terraform.tfvars`:**

```hcl
aws_region  = "us-east-1"
project     = "myapp"
environment = "prod"
bucket_suffix = "data-archive"

enable_versioning   = true
block_public_access = true

lifecycle_rules = [
  {
    id     = "standard-tiering"
    status = "Enabled"
    transitions = [
      { days = 30,  storage_class = "STANDARD_IA" },
      { days = 90,  storage_class = "GLACIER" },
      { days = 180, storage_class = "DEEP_ARCHIVE" }
    ]
    expiration = { days = 365 }
    noncurrent_version_transitions = [
      { days = 30, storage_class = "STANDARD_IA" }
    ]
    noncurrent_version_expiration = { days = 90 }
  }
]

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
| `bucket_name` | `string` | `""` | Explicit bucket name; overrides the auto-generated `{project}-{environment}-{bucket_suffix}` name |
| `bucket_suffix` | `string` | `"data"` | Suffix for the auto-generated bucket name (e.g., `assets`, `logs`, `archive`) |
| `force_destroy` | `bool` | `false` | Allow Terraform to delete the bucket even when it contains objects |
| `enable_versioning` | `bool` | `true` | Enable object versioning |
| `use_kms` | `bool` | `false` | Use SSE-KMS encryption instead of SSE-S3 (AES256) |
| `kms_key_id` | `string` | `null` | KMS key ARN to use for SSE-KMS (required when `use_kms = true`) |
| `block_public_access` | `bool` | `true` | Block all public access (ACLs and bucket policies) |
| `enable_access_logging` | `bool` | `false` | Create a separate logging bucket and enable S3 server access logging |
| `bucket_policy` | `string` | `""` | JSON IAM policy document to attach to the bucket |
| `lifecycle_rules` | `list(object)` | `[]` | Lifecycle rules for tiering and expiring objects (see Customization section) |
| `cors_rules` | `list(object)` | `[]` | CORS rules for browser-based access (see Customization section) |
| `lambda_notifications` | `list(object)` | `[]` | Lambda function event notifications; each object requires `lambda_arn`, `events`, and optional `filter_prefix`/`filter_suffix` |
| `sqs_notifications` | `list(object)` | `[]` | SQS queue event notifications; each object requires `queue_arn`, `events`, and optional `filter_prefix`/`filter_suffix` |
| `tags` | `map(string)` | `{}` | Tags applied to all resources |

---

## Outputs Reference

| Output | Description |
|---|---|
| `bucket_id` | The name of the S3 bucket (same as the bucket name) |
| `bucket_arn` | The ARN of the S3 bucket |
| `bucket_domain_name` | Global bucket domain name (`{bucket}.s3.amazonaws.com`) |
| `bucket_regional_domain_name` | Regional bucket domain name (`{bucket}.s3.{region}.amazonaws.com`); use this for CloudFront origins |
| `bucket_region` | The AWS region where the bucket was created |
| `access_log_bucket_id` | The name of the access log bucket (null when `enable_access_logging = false`) |

---

## Customization

### Lifecycle rules

Lifecycle rules reduce storage costs by automatically moving objects to cheaper storage classes and expiring old versions. The template accepts a list of rule objects:

```hcl
lifecycle_rules = [
  {
    id     = "cost-optimization"
    status = "Enabled"

    # Current version transitions
    transitions = [
      { days = 30,  storage_class = "STANDARD_IA" },   # ~46% cost reduction
      { days = 90,  storage_class = "GLACIER" },        # ~72% cost reduction
      { days = 180, storage_class = "DEEP_ARCHIVE" }    # ~95% cost reduction
    ]

    # Delete current versions after 1 year
    expiration = { days = 365 }

    # Move noncurrent versions to IA after 30 days
    noncurrent_version_transitions = [
      { days = 30, storage_class = "STANDARD_IA" }
    ]

    # Permanently delete noncurrent versions after 90 days
    noncurrent_version_expiration = { days = 90 }
  }
]
```

### CORS for Single-Page Application (SPA) hosting

To allow a browser-based SPA to upload directly to S3 or read objects:

```hcl
cors_rules = [
  {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["https://www.myapp.com", "https://staging.myapp.com"]
    expose_headers  = ["ETag", "x-amz-request-id"]
    max_age_seconds = 3000
  }
]
```

For development, you can temporarily use `["*"]` as `allowed_origins`, but restrict to specific domains in production.

### Attaching a bucket policy

Pass a JSON policy string to restrict or grant access. For example, to require HTTPS-only access:

```hcl
bucket_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Sid       = "DenyHTTP"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [
        "arn:aws:s3:::myapp-prod-assets",
        "arn:aws:s3:::myapp-prod-assets/*"
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }
  ]
})
```

### Configuring event notifications

**Lambda notification** — trigger a function on every new object upload in the `uploads/` prefix:

```hcl
lambda_notifications = [
  {
    lambda_arn    = "arn:aws:lambda:us-east-1:123456789012:function:process-upload"
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
    filter_suffix = ".jpg"
  }
]
```

**SQS notification** — fanout object creation events to a queue for async processing:

```hcl
sqs_notifications = [
  {
    queue_arn = "arn:aws:sqs:us-east-1:123456789012:object-events"
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
]
```

The SQS queue or Lambda function must have a resource-based policy that allows `s3.amazonaws.com` to invoke it.

---

## Common Use Cases

### Static website hosting

S3 can host a static website, but the native website endpoint is plain HTTP. The recommended pattern for HTTPS is to place a CloudFront distribution in front:

```hcl
project       = "myapp"
environment   = "prod"
bucket_suffix = "website"

block_public_access = true   # keep private; CloudFront uses OAC to access
enable_versioning   = true

cors_rules = [
  {
    allowed_headers = ["Authorization", "Content-Length"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["https://www.myapp.com"]
    max_age_seconds = 86400
  }
]
```

Reference `bucket_regional_domain_name` as the CloudFront origin domain name to ensure requests are routed to the correct region.

### Data lake

For analytics workloads, enable lifecycle tiering and use a structured prefix convention so individual prefixes can have independent lifecycle rules:

```hcl
bucket_suffix = "datalake"
enable_versioning = true

lifecycle_rules = [
  {
    id     = "raw-to-glacier"
    status = "Enabled"
    transitions = [
      { days = 90, storage_class = "GLACIER" }
    ]
  }
]
```

Partition data as `s3://{bucket}/raw/year=2025/month=01/day=15/` so Athena and Glue can discover partitions automatically.

### Application artifacts and deployments

Store build artifacts, Lambda ZIP packages, and container image layers. Enable versioning so deployments can be rolled back:

```hcl
bucket_suffix     = "artifacts"
enable_versioning = true
force_destroy     = false   # protect against accidental deletion in prod

lifecycle_rules = [
  {
    id     = "prune-old-artifacts"
    status = "Enabled"
    noncurrent_version_expiration = { days = 30 }
  }
]
```

Grant CodePipeline or CodeBuild access via a bucket policy scoped to the specific service role ARNs.
