# SNS + SQS Terraform Template

## Overview

This template provisions SNS topics and SQS queues with optional SNS-to-SQS subscriptions for fan-out messaging patterns. KMS encryption is supported for both services.

**Resources created:**

- **SNS Topics** — standard or FIFO; supports display names and custom access policies
- **SQS Queues** — standard or FIFO with configurable retention, visibility timeout, and delay
- **Dead-Letter Queues (DLQs)** — automatically paired with each SQS queue; messages are moved here after `max_receive_count` failed delivery attempts
- **SNS-to-SQS Subscriptions** — fan-out wiring with optional filter policies and raw message delivery
- **KMS Key** — single customer-managed key encrypts all topics and queues when `encrypt_at_rest = true`
- **SQS Queue Policies** — automatically grants SNS permission to send messages to subscribed queues

---

## Quick Start

### Fan-Out: One SNS Topic to Multiple SQS Queues

```hcl
module "messaging" {
  source = "../sns-sqs"

  project     = "myapp"
  environment = "prod"
  aws_region  = "us-east-1"

  encrypt_at_rest = true

  sns_topics = {
    orders = {
      display_name = "Order Events"
    }
  }

  sqs_queues = {
    fulfillment = {
      visibility_timeout = 60
      enable_dlq         = true
      max_receive_count  = 3
    }
    notifications = {
      visibility_timeout = 30
      enable_dlq         = true
      max_receive_count  = 5
    }
    analytics = {
      visibility_timeout = 120
      retention_seconds  = 1209600  # 14 days
      enable_dlq         = true
    }
  }

  sns_sqs_subscriptions = {
    orders_to_fulfillment = {
      topic_key = "orders"
      queue_key = "fulfillment"
    }
    orders_to_notifications = {
      topic_key            = "orders"
      queue_key            = "notifications"
      raw_message_delivery = true
    }
    orders_to_analytics = {
      topic_key = "orders"
      queue_key = "analytics"
    }
  }

  tags = {
    Domain = "commerce"
  }
}
```

### FIFO Topic and Queue (Ordered Processing)

```hcl
module "ordered_messaging" {
  source = "../sns-sqs"

  project     = "myapp"
  environment = "prod"
  aws_region  = "us-east-1"

  sns_topics = {
    inventory_updates = {
      display_name                = "Inventory Updates"
      fifo                        = true
      content_based_deduplication = true
    }
  }

  sqs_queues = {
    inventory_processor = {
      fifo                        = true
      content_based_deduplication = true
      visibility_timeout          = 90
      enable_dlq                  = true
      max_receive_count           = 3
    }
  }

  sns_sqs_subscriptions = {
    inventory_sub = {
      topic_key = "inventory_updates"
      queue_key = "inventory_processor"
    }
  }

  tags = {
    Domain = "inventory"
  }
}
```

### terraform.tfvars Example

```hcl
project     = "myapp"
environment = "prod"
aws_region  = "us-east-1"

encrypt_at_rest = true

sns_topics = {
  orders = {
    display_name = "Order Events"
  }
}

sqs_queues = {
  fulfillment = {
    visibility_timeout = 60
    retention_seconds  = 345600
    enable_dlq         = true
    max_receive_count  = 3
  }
}

sns_sqs_subscriptions = {
  orders_to_fulfillment = {
    topic_key = "orders"
    queue_key = "fulfillment"
  }
}

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
| `project` | `string` | — | Project name |
| `environment` | `string` | — | Environment: dev, staging, or prod |
| `encrypt_at_rest` | `bool` | `true` | Encrypt all topics and queues using a customer-managed KMS key |
| `sns_topics` | `map(object)` | `{}` | Map of SNS topics to create (see schema below) |
| `sqs_queues` | `map(object)` | `{}` | Map of SQS queues to create (see schema below) |
| `sns_sqs_subscriptions` | `map(object)` | `{}` | Map of SNS-to-SQS subscriptions to create |
| `tags` | `map(string)` | `{}` | Tags applied to all resources |

**`sns_topics` object schema:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `display_name` | `string` | `""` | Human-readable display name for the topic |
| `fifo` | `bool` | `false` | Create a FIFO topic (name will have `.fifo` suffix) |
| `content_based_deduplication` | `bool` | `false` | Enable content-based deduplication (FIFO topics only) |
| `policy` | `string` | `""` | Custom SNS access policy JSON |

**`sqs_queues` object schema:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `fifo` | `bool` | `false` | Create a FIFO queue |
| `content_based_deduplication` | `bool` | `false` | Enable content-based deduplication (FIFO only) |
| `visibility_timeout` | `number` | `30` | Seconds a message is hidden after being received |
| `retention_seconds` | `number` | `345600` | Message retention period (4 days default; max 14 days) |
| `max_message_size` | `number` | `262144` | Maximum message size in bytes (max 256 KB) |
| `delay_seconds` | `number` | `0` | Seconds to delay delivery of new messages |
| `receive_wait_time` | `number` | `0` | Seconds for long polling (0 = short poll; up to 20) |
| `enable_dlq` | `bool` | `true` | Automatically create and attach a dead-letter queue |
| `max_receive_count` | `number` | `3` | Failed receive attempts before routing to DLQ |
| `policy` | `string` | `""` | Custom SQS access policy JSON |

**`sns_sqs_subscriptions` object schema:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `topic_key` | `string` | — | Key of the SNS topic from `sns_topics` |
| `queue_key` | `string` | — | Key of the SQS queue from `sqs_queues` |
| `raw_message_delivery` | `bool` | `false` | Deliver raw message body without SNS envelope |
| `filter_policy` | `string` | `null` | JSON filter policy to selectively route messages |

---

## Outputs

| Name | Description |
|------|-------------|
| `sns_topic_arns` | Map of topic key to ARN |
| `sqs_queue_urls` | Map of queue key to URL |
| `sqs_queue_arns` | Map of queue key to ARN |
| `sqs_dlq_arns` | Map of dead-letter queue key to ARN |
| `kms_key_arn` | ARN of the KMS key used for encryption (null if disabled) |

---

## Customization

### FIFO Queues for Strict Ordering

FIFO queues guarantee that messages are processed exactly once and in order within a message group. Both the topic and queue must be FIFO.

```hcl
sns_topics = {
  payments = {
    fifo                        = true
    content_based_deduplication = true
  }
}

sqs_queues = {
  payment_processor = {
    fifo                        = true
    content_based_deduplication = true
    visibility_timeout          = 120
  }
}
```

FIFO topics and queues have lower throughput limits (300 API calls/second per queue) compared to standard queues (up to 120,000 messages/second). Use FIFO only when ordering guarantees are required.

### Filter Policies on Subscriptions

Filter policies allow a queue to receive only a subset of messages from a topic, eliminating the need to filter messages in your consumer:

```hcl
sns_sqs_subscriptions = {
  # Only route "order.created" events to the fulfillment queue
  orders_to_fulfillment = {
    topic_key = "orders"
    queue_key = "fulfillment"
    filter_policy = jsonencode({
      event_type = ["order.created", "order.updated"]
    })
  }

  # Only route high-value orders to the priority queue
  high_value_orders = {
    topic_key = "orders"
    queue_key = "priority_fulfillment"
    filter_policy = jsonencode({
      order_value = [{ numeric = [">=", 1000] }]
    })
  }
}
```

Your SNS publisher must include message attributes that match the filter policy keys.

### Message Retention Tuning

```hcl
sqs_queues = {
  analytics = {
    retention_seconds = 1209600   # 14 days (maximum)
    visibility_timeout = 300      # 5 minutes for heavy processing
    receive_wait_time  = 20       # Enable long polling to reduce empty receives
  }
}
```

Set `receive_wait_time = 20` to enable long polling, which reduces API calls and costs by waiting up to 20 seconds for messages to arrive before returning an empty response.

### Visibility Timeout Tuning

The visibility timeout must be longer than the time your consumer takes to process a message, including any downstream API calls:

```hcl
sqs_queues = {
  email_sender = {
    visibility_timeout = 60    # must exceed your lambda/worker processing time
    max_receive_count  = 3     # retry 3 times before DLQ
  }
}
```

If your Lambda function has a 30-second timeout, set the visibility timeout to at least 60 seconds to allow for retries and clock skew.

### DLQ Monitoring with CloudWatch Alarms

After deploying, add a CloudWatch alarm to alert when messages land in a DLQ:

```hcl
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "myapp-prod-fulfillment-dlq"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    QueueName = "${module.messaging.sqs_queue_urls["fulfillment"]}-dlq"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

A non-zero DLQ depth indicates processing failures and should trigger an on-call alert.
