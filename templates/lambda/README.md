# Lambda Terraform Template

Provisions an AWS Lambda function with all supporting infrastructure: a CloudWatch log group, an IAM execution role, an optional VPC security group, an optional Lambda layer, provisioned concurrency via an alias, event source mappings, and an optional function URL for direct HTTPS invocation.

## Resources Created

| Resource | Description |
|---|---|
| `aws_cloudwatch_log_group` | Pre-created log group with configurable retention |
| `aws_iam_role` | Lambda execution role with basic execution policy |
| `aws_iam_role_policy` | Optional custom inline policy attached to the role |
| `aws_security_group` | Security group for VPC-deployed functions (when `deploy_in_vpc = true`) |
| `aws_lambda_layer_version` | Lambda layer built from a local zip (when `create_layer = true`) |
| `aws_lambda_function` | The Lambda function |
| `aws_lambda_alias` | Alias pointing to the published version (when `provisioned_concurrency > 0`) |
| `aws_lambda_provisioned_concurrency_config` | Provisioned concurrency on the alias (when `provisioned_concurrency > 0`) |
| `aws_lambda_event_source_mapping` | One per entry in `event_source_mappings` |
| `aws_lambda_function_url` | Direct HTTPS endpoint (when `create_function_url = true`) |

## Prerequisites

- Terraform >= 1.3
- AWS provider >= 5.0
- Your function code must be **packaged as a zip file** before running Terraform (see [Packaging Your Function](#packaging-your-function))
- For VPC deployment: an existing VPC with private subnets
- For event source mappings: the source resource (SQS queue, DynamoDB stream, Kinesis stream) must already exist

## Packaging Your Function

Terraform reads a local zip file and uploads it to Lambda. Create the zip before running `terraform apply`.

### Python

```bash
# Single-file function
zip function.zip lambda_function.py

# Function with dependencies
pip install -r requirements.txt -t package/
cp lambda_function.py package/
cd package && zip -r ../function.zip . && cd ..
```

### Node.js

```bash
# Install production dependencies
npm ci --omit=dev

# Zip everything (node_modules included)
zip -r function.zip index.js node_modules/

# Or with a build step
npm run build
zip -r function.zip dist/ node_modules/
```

### Lambda Layer (dependencies only)

Layers must follow the required directory structure for the runtime:

```bash
# Python layer — files must be under python/
mkdir -p layer/python
pip install -r requirements.txt -t layer/python/
cd layer && zip -r ../layer.zip . && cd ..
```

```bash
# Node.js layer — files must be under nodejs/node_modules/
mkdir -p layer/nodejs
cp package.json layer/nodejs/
cd layer/nodejs && npm ci --omit=dev && cd ../..
cd layer && zip -r ../layer.zip . && cd ..
```

---

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

### Example: Simple Public Function

```hcl
# terraform.tfvars

aws_region    = "us-east-1"
function_name = "my-api-handler"
description   = "Handles API Gateway requests for the myapp service"

runtime      = "python3.12"
handler      = "lambda_function.lambda_handler"
filename     = "function.zip"
timeout      = 30
memory_size  = 256
architecture = "arm64"

environment_variables = {
  LOG_LEVEL    = "INFO"
  SERVICE_NAME = "myapp"
}

log_retention_days  = 30
reserved_concurrency = -1

create_function_url     = true
function_url_auth_type  = "NONE"
function_url_cors = {
  allow_origins = ["https://myapp.example.com"]
  allow_methods = ["GET", "POST"]
  allow_headers = ["Content-Type", "Authorization"]
}

tags = {
  Team = "backend"
}
```

### Example: VPC-Deployed Function with SQS Trigger

```hcl
# terraform.tfvars

aws_region    = "us-east-1"
function_name = "order-processor"
description   = "Processes orders from the SQS queue"

runtime      = "python3.12"
handler      = "handler.process"
filename     = "function.zip"
timeout      = 120
memory_size  = 512
architecture = "arm64"

environment_variables = {
  DB_SECRET_ARN = "arn:aws:secretsmanager:us-east-1:123456789012:secret:myapp/prod/db-abc123"
  ENVIRONMENT   = "prod"
}

deploy_in_vpc = true
vpc_id        = "vpc-0abc123456789def0"
subnet_ids    = ["subnet-0aaa111111111111a", "subnet-0bbb222222222222b"]

event_source_mappings = {
  orders_queue = {
    event_source_arn = "arn:aws:sqs:us-east-1:123456789012:orders-prod"
    batch_size       = 10
    enabled          = true
  }
}

dead_letter_target_arn = "arn:aws:sqs:us-east-1:123456789012:orders-dlq-prod"

enable_xray = true

custom_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:us-east-1:123456789012:secret:myapp/prod/*"
    },
    {
      Effect   = "Allow"
      Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      Resource = "arn:aws:sqs:us-east-1:123456789012:orders-prod"
    }
  ]
})

provisioned_concurrency = 2
log_retention_days      = 90

tags = {
  Team      = "backend"
  Component = "order-processing"
}
```

---

## Variables Reference

| Variable | Type | Default | Description |
|---|---|---|---|
| `aws_region` | `string` | `"us-east-1"` | AWS region to deploy into |
| `function_name` | `string` | — | Name of the Lambda function |
| `description` | `string` | `""` | Human-readable description of the function |
| `runtime` | `string` | `"python3.12"` | Lambda runtime identifier (e.g., `python3.12`, `nodejs20.x`, `java17`, `go1.x`) |
| `handler` | `string` | `"index.handler"` | Entry point in the format `file.function` (e.g., `lambda_function.lambda_handler`) |
| `filename` | `string` | `"function.zip"` | Path to the local deployment zip. Used when `s3_bucket` is empty |
| `s3_bucket` | `string` | `""` | S3 bucket containing the deployment package. Takes precedence over `filename` when set |
| `s3_key` | `string` | `""` | S3 object key for the deployment package (required when `s3_bucket` is set) |
| `timeout` | `number` | `30` | Maximum execution time in seconds (1–900) |
| `memory_size` | `number` | `128` | Memory allocated to the function in MB (128–10240) |
| `architecture` | `string` | `"arm64"` | Instruction set: `arm64` (Graviton, ~20% cheaper) or `x86_64` |
| `environment_variables` | `map(string)` | `{}` | Key-value pairs exposed as environment variables inside the function |
| `log_retention_days` | `number` | `14` | CloudWatch Logs retention period in days |
| `deploy_in_vpc` | `bool` | `false` | Deploy the function inside a VPC (required for accessing VPC resources like RDS) |
| `vpc_id` | `string` | `""` | VPC ID (required when `deploy_in_vpc = true`) |
| `subnet_ids` | `list(string)` | `[]` | Private subnet IDs for VPC deployment (required when `deploy_in_vpc = true`) |
| `custom_policy` | `string` | `""` | JSON string of an IAM policy document to attach as an inline policy to the Lambda role |
| `dead_letter_target_arn` | `string` | `""` | ARN of an SQS queue or SNS topic to receive failed invocation records |
| `enable_xray` | `bool` | `false` | Enable AWS X-Ray active tracing |
| `reserved_concurrency` | `number` | `-1` | Reserved concurrency limit. `-1` means unreserved (shares account pool). `0` throttles the function completely |
| `provisioned_concurrency` | `number` | `0` | Number of execution environments to keep pre-initialized. Requires publishing a version; an alias is created automatically |
| `create_layer` | `bool` | `false` | Create a Lambda layer from a local zip file |
| `layer_filename` | `string` | `""` | Path to the layer zip file (required when `create_layer = true`) |
| `additional_layer_arns` | `list(string)` | `[]` | ARNs of existing Lambda layers to attach (max 5 total layers including any created by this module) |
| `event_source_mappings` | `map(object)` | `{}` | Event source mappings for SQS, DynamoDB Streams, or Kinesis. Each key becomes the mapping's logical name. See schema below |
| `create_function_url` | `bool` | `false` | Create a Lambda function URL for direct HTTPS invocation (no API Gateway required) |
| `function_url_auth_type` | `string` | `"AWS_IAM"` | Auth type for the function URL: `AWS_IAM` (sigv4 required) or `NONE` (public) |
| `function_url_cors` | `object` | `null` | CORS configuration with `allow_origins`, `allow_methods`, and `allow_headers` lists. Set to `null` to disable CORS |
| `tags` | `map(string)` | `{}` | Additional tags applied to all resources |

### `event_source_mappings` Object Schema

```hcl
event_source_mappings = {
  "<logical_name>" = {
    event_source_arn  = string           # ARN of the SQS queue, DynamoDB stream, or Kinesis stream
    starting_position = optional(string) # "LATEST" or "TRIM_HORIZON" — required for streams, null for SQS
    batch_size        = optional(number) # Records per invocation (default: 10)
    enabled           = optional(bool)   # Whether the mapping is active (default: true)
  }
}
```

---

## Outputs Reference

| Output | Description |
|---|---|
| `function_name` | The name of the Lambda function |
| `function_arn` | The ARN of the Lambda function |
| `function_invoke_arn` | The invocation ARN used to configure API Gateway integrations |
| `function_version` | The latest published version number |
| `role_arn` | ARN of the Lambda execution IAM role |
| `role_name` | Name of the Lambda execution IAM role (use to attach additional policies) |
| `log_group_name` | Name of the CloudWatch log group |
| `function_url` | The HTTPS function URL (populated when `create_function_url = true`, otherwise `null`) |
| `layer_arn` | ARN of the Lambda layer (populated when `create_layer = true`, otherwise `null`) |

---

## Customization

### Deploying from S3 Instead of a Local File

Store large deployment packages in S3 to avoid Terraform state size issues and to share packages across environments:

```bash
# Upload the package
aws s3 cp function.zip s3://my-deployments-bucket/myapp/function.zip
```

```hcl
s3_bucket = "my-deployments-bucket"
s3_key    = "myapp/function.zip"
filename  = ""   # must be empty when using S3
```

### Adding Environment Variables

```hcl
environment_variables = {
  DATABASE_URL = "postgresql://host:5432/dbname"
  LOG_LEVEL    = "DEBUG"
  FEATURE_FLAG = "true"
}
```

Sensitive values should be stored in Secrets Manager or SSM Parameter Store. Pass the ARN/path as an environment variable and retrieve the value inside the function at runtime.

### Configuring SQS Event Source Mapping

```hcl
event_source_mappings = {
  main_queue = {
    event_source_arn = "arn:aws:sqs:us-east-1:123456789012:my-queue"
    batch_size       = 5
    enabled          = true
    # starting_position is not used for SQS — omit it
  }
}
```

The Lambda execution role must have `sqs:ReceiveMessage`, `sqs:DeleteMessage`, and `sqs:GetQueueAttributes` permissions on the queue. Provide these via `custom_policy`.

### Configuring a Kinesis or DynamoDB Stream Mapping

```hcl
event_source_mappings = {
  orders_stream = {
    event_source_arn  = "arn:aws:kinesis:us-east-1:123456789012:stream/orders"
    starting_position = "LATEST"   # or "TRIM_HORIZON" to reprocess from the beginning
    batch_size        = 100
  }
}
```

### Enabling X-Ray Tracing

```hcl
enable_xray = true
```

X-Ray tracing adds the `AWSXRayDaemonWriteAccess` managed policy to the Lambda role automatically and sets the tracing mode to `Active`. Instrument your code with the X-Ray SDK to generate subsegment traces for downstream calls.

### Choosing arm64 vs x86_64

| Architecture | When to use |
|---|---|
| `arm64` | Default recommendation. ~20% lower cost per GB-second, same or better performance for most workloads. Requires that all native extensions/binaries in your package are compiled for `linux/arm64` |
| `x86_64` | Required for runtimes or native dependencies that do not have ARM builds (e.g., some legacy Java libraries, certain ML inference packages) |

### Function URL vs API Gateway

| | Function URL | API Gateway |
|---|---|---|
| **Best for** | Webhooks, simple REST, internal services | Complex APIs, request transformation, throttling, usage plans |
| **Latency** | Lower (no extra hop) | Slightly higher |
| **Auth** | `AWS_IAM` (sigv4) or `NONE` | API keys, Cognito, IAM, Lambda authorizers |
| **Cost** | Included with Lambda invocation cost | Per-request charge on top of Lambda |
| **Custom domain** | Not supported natively | Supported via API Gateway custom domains |

Enable a function URL:

```hcl
create_function_url    = true
function_url_auth_type = "NONE"   # set "AWS_IAM" for private internal use
```

The URL is available in the `function_url` output after apply.
