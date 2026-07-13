# DynamoDB Terraform Template

## Overview

This template provisions a DynamoDB table with enterprise-grade features including indexing, encryption, backups, and optional global replication.

**Resources created:**

- **DynamoDB Table** with configurable partition key, optional sort key, billing mode, and class
- **Global Secondary Indexes (GSIs)** — up to 20, with custom key schema and projections
- **Local Secondary Indexes (LSIs)** — must be defined at table creation time
- **TTL** — automatic item expiration on a nominated attribute
- **DynamoDB Streams** — ordered change log for event-driven integrations
- **Encryption** — AWS-managed key (default) or customer-managed KMS key
- **Point-in-Time Recovery (PITR)** — continuous backups with 35-day restore window
- **Global Tables (replica regions)** — multi-region active-active replication
- **Auto Scaling** (PROVISIONED mode only) — read/write capacity scales automatically

---

## Quick Start

### Simple Key-Value Table (On-Demand)

```hcl
module "sessions_table" {
  source = "../dynamodb"

  project     = "myapp"
  environment = "prod"
  aws_region  = "us-east-1"

  table_name   = "sessions"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "session_id"
  range_key = ""

  attributes = [
    { name = "session_id", type = "S" }
  ]

  ttl_attribute = "expires_at"
  enable_pitr   = true

  tags = {
    Team = "platform"
  }
}
```

### Table with GSI for Secondary Access Patterns

```hcl
module "orders_table" {
  source = "../dynamodb"

  project     = "myapp"
  environment = "prod"
  aws_region  = "us-east-1"

  table_name   = "orders"
  billing_mode = "PROVISIONED"
  read_capacity  = 10
  write_capacity = 5

  hash_key  = "order_id"
  range_key = "created_at"

  attributes = [
    { name = "order_id",    type = "S" },
    { name = "created_at",  type = "S" },
    { name = "customer_id", type = "S" },
    { name = "status",      type = "S" }
  ]

  global_secondary_indexes = [
    {
      name            = "customer-orders-index"
      hash_key        = "customer_id"
      range_key       = "created_at"
      projection_type = "ALL"
    },
    {
      name            = "status-index"
      hash_key        = "status"
      range_key       = "created_at"
      projection_type = "INCLUDE"
      non_key_attributes = ["order_id", "customer_id", "total"]
    }
  ]

  enable_streams    = true
  stream_view_type  = "NEW_AND_OLD_IMAGES"

  enable_autoscaling    = true
  autoscaling_read_min  = 5
  autoscaling_read_max  = 100
  autoscaling_write_min = 5
  autoscaling_write_max = 50

  tags = {
    Domain = "commerce"
  }
}
```

### terraform.tfvars Example

```hcl
project     = "myapp"
environment = "prod"
aws_region  = "us-east-1"

table_name   = "orders"
billing_mode = "PAY_PER_REQUEST"

hash_key  = "pk"
range_key = "sk"

attributes = [
  { name = "pk",          type = "S" },
  { name = "sk",          type = "S" },
  { name = "customer_id", type = "S" }
]

global_secondary_indexes = [
  {
    name            = "gsi-customer"
    hash_key        = "customer_id"
    range_key       = "sk"
    projection_type = "ALL"
  }
]

ttl_attribute = "ttl"
enable_pitr   = true

tags = {
  Environment = "prod"
  Team        = "backend"
}
```

---

## Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `aws_region` | `string` | `"us-east-1"` | AWS region |
| `project` | `string` | — | Project name (used in resource naming) |
| `environment` | `string` | — | Environment: dev, staging, or prod |
| `table_name` | `string` | — | Table name suffix (full name: `project-environment-table_name`) |
| `billing_mode` | `string` | `"PAY_PER_REQUEST"` | `PAY_PER_REQUEST` (on-demand) or `PROVISIONED` |
| `hash_key` | `string` | — | Name of the partition (hash) key attribute |
| `range_key` | `string` | `""` | Name of the sort (range) key attribute; leave empty for none |
| `attributes` | `list(object)` | — | All indexed attribute definitions (`name`, `type`: S/N/B) |
| `read_capacity` | `number` | `5` | Provisioned read capacity units (PROVISIONED mode only) |
| `write_capacity` | `number` | `5` | Provisioned write capacity units (PROVISIONED mode only) |
| `ttl_attribute` | `string` | `""` | Attribute name for TTL auto-expiration; leave empty to disable |
| `enable_pitr` | `bool` | `true` | Enable Point-in-Time Recovery (35-day rolling window) |
| `use_custom_kms` | `bool` | `false` | Use a customer-managed KMS key instead of the AWS-managed key |
| `kms_key_arn` | `string` | `null` | KMS key ARN (required when `use_custom_kms = true`) |
| `enable_streams` | `bool` | `false` | Enable DynamoDB Streams |
| `stream_view_type` | `string` | `"NEW_AND_OLD_IMAGES"` | Stream record content: `KEYS_ONLY`, `NEW_IMAGE`, `OLD_IMAGE`, or `NEW_AND_OLD_IMAGES` |
| `global_secondary_indexes` | `list(object)` | `[]` | GSI definitions (name, hash\_key, range\_key, projection\_type, etc.) |
| `local_secondary_indexes` | `list(object)` | `[]` | LSI definitions (must be set at table creation; cannot be added later) |
| `replica_regions` | `list(string)` | `[]` | Additional regions for Global Tables replication |
| `enable_autoscaling` | `bool` | `false` | Enable auto scaling (PROVISIONED mode only) |
| `autoscaling_read_min` | `number` | `5` | Minimum read capacity for auto scaling |
| `autoscaling_read_max` | `number` | `100` | Maximum read capacity for auto scaling |
| `autoscaling_write_min` | `number` | `5` | Minimum write capacity for auto scaling |
| `autoscaling_write_max` | `number` | `100` | Maximum write capacity for auto scaling |
| `tags` | `map(string)` | `{}` | Tags applied to all resources |

---

## Outputs

| Name | Description |
|------|-------------|
| `table_id` | The DynamoDB table name (same as `table_name` output) |
| `table_arn` | The ARN of the DynamoDB table |
| `table_name` | The full name of the DynamoDB table |
| `stream_arn` | The ARN of the DynamoDB stream (null when streams are disabled) |
| `stream_label` | The timestamp identifying the stream (null when disabled) |

---

## Customization

### Billing Mode: PAY\_PER\_REQUEST vs PROVISIONED

**PAY\_PER\_REQUEST** (default) is ideal for unpredictable or low-volume workloads. You pay per request with no capacity planning required.

**PROVISIONED** is more cost-effective at sustained, predictable traffic. Pair it with auto scaling to handle variable loads without over-provisioning:

```hcl
billing_mode   = "PROVISIONED"
read_capacity  = 10
write_capacity = 5

enable_autoscaling    = true
autoscaling_read_min  = 5
autoscaling_read_max  = 200
autoscaling_write_min = 5
autoscaling_write_max = 100
```

### Adding Global Secondary Indexes

GSIs allow you to query on non-primary-key attributes. Define every indexed attribute in the `attributes` list:

```hcl
attributes = [
  { name = "user_id",    type = "S" },
  { name = "created_at", type = "S" },
  { name = "email",      type = "S" }
]

global_secondary_indexes = [
  {
    name            = "email-index"
    hash_key        = "email"
    projection_type = "KEYS_ONLY"
  },
  {
    name            = "user-timeline-index"
    hash_key        = "user_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }
]
```

GSIs with `projection_type = "ALL"` replicate the full item but cost more. Use `KEYS_ONLY` or `INCLUDE` to reduce storage and write costs.

### Enabling Global Tables for Multi-Region

Global Tables provide active-active multi-region replication with single-digit millisecond latency in each region.

```hcl
billing_mode    = "PAY_PER_REQUEST"  # Global Tables requires on-demand or autoscaled PROVISIONED
replica_regions = ["eu-west-1", "ap-southeast-1"]
```

The table must use PAY\_PER\_REQUEST or have auto scaling enabled on all replicas.

### Using DynamoDB Streams with Lambda

Enable streams to trigger Lambda on item changes (inserts, updates, deletes):

```hcl
enable_streams   = true
stream_view_type = "NEW_AND_OLD_IMAGES"
```

Then create an event source mapping in your Lambda module:

```hcl
resource "aws_lambda_event_source_mapping" "dynamodb" {
  event_source_arn  = module.orders_table.stream_arn
  function_name     = aws_lambda_function.processor.arn
  starting_position = "LATEST"
  batch_size        = 100
}
```

`NEW_AND_OLD_IMAGES` is recommended when you need to compute diffs (e.g., detect what changed in an order).

### TTL for Session Management

Set `ttl_attribute` to automatically expire items without running a cleanup job:

```hcl
ttl_attribute = "expires_at"
```

Write the expiry as a Unix epoch timestamp in your application:

```python
import time
item = {
    "session_id": session_id,
    "user_id": user_id,
    "expires_at": int(time.time()) + 3600  # 1 hour from now
}
```

DynamoDB deletes expired items within 48 hours of the TTL timestamp. Deleted items still appear in streams with an event type of `REMOVE`.
