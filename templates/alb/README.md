# ALB Terraform Template

Provisions an internet-facing (or internal) Application Load Balancer with a security group, one or more target groups, an HTTP listener, an optional HTTPS listener with TLS termination, and configurable path-based or host-based listener rules. Access logs can be written to an S3 bucket.

## Resources Created

| Resource | Description |
|---|---|
| `aws_security_group` | Controls inbound HTTP/HTTPS traffic to the ALB |
| `aws_lb` | The Application Load Balancer |
| `aws_s3_bucket_policy` | Policy granting the ALB service account write access for access logs (when `enable_access_logs = true`) |
| `aws_lb_target_group` | One target group per entry in the `target_groups` map |
| `aws_lb_listener` (HTTP) | HTTP listener on port 80 — forwards to the default target group or redirects to HTTPS |
| `aws_lb_listener` (HTTPS) | HTTPS listener on port 443 (when `https_certificate_arn` is provided) |
| `aws_lb_listener_rule` | One rule per entry in the `listener_rules` map, enabling path/host-based routing |

## Architecture

```
                         ┌─────────────────────────────────────────────────┐
                         │                  AWS Region                      │
                         │                                                  │
   Internet              │   ┌─────────────────────────────────────────┐   │
      │                  │   │         Application Load Balancer        │   │
      │  HTTP :80        │   │                                          │   │
      ├─────────────────────►│  Listener Rules (path / host based)     │   │
      │  HTTPS :443      │   │                                          │   │
      └─────────────────────►│  ┌──────────┐  ┌──────────┐  ┌──────┐  │   │
                         │   │  │  TG: web │  │ TG: api  │  │TG:...|  │   │
                         │   └──┴────┬─────┴──┴────┬─────┴──┴──┬───┘  │   │
                         │           │              │            │       │   │
                         │    ┌──────┘      ┌───────┘     ┌─────┘       │   │
                         │    ▼             ▼             ▼             │   │
                         │  ┌──────┐    ┌──────┐    ┌──────┐           │   │
                         │  │  EC2 │    │  EC2 │    │ ECS  │           │   │
                         │  │  /   │    │  /   │    │ Task │           │   │
                         │  │ ECS  │    │ ECS  │    │      │           │   │
                         │  └──────┘    └──────┘    └──────┘           │   │
                         │                                              │   │
                         └──────────────────────────────────────────────┘   │
                         └─────────────────────────────────────────────────┘
```

## Prerequisites

- Terraform >= 1.3
- AWS provider >= 5.0
- An existing VPC with **public subnets** in at least two Availability Zones (for internet-facing ALBs)
- An ACM certificate in the **same region** as the ALB if you want an HTTPS listener
- Target resources (EC2 instances or ECS services) that will be registered with the target groups

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

### Example: Multi-Service ALB with Path-Based Routing

```hcl
# terraform.tfvars

aws_region  = "us-east-1"
project     = "myapp"
environment = "prod"

vpc_id     = "vpc-0abc123456789def0"
subnet_ids = ["subnet-0pub111111111111a", "subnet-0pub222222222222b"]

internal             = false
allowed_cidr_blocks  = ["0.0.0.0/0"]
idle_timeout         = 60
enable_deletion_protection = true

# HTTPS — provide a validated ACM certificate
https_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc12345-1234-1234-1234-abcdef123456"
ssl_policy            = "ELBSecurityPolicy-TLS13-1-2-2021-06"

# Access logs
enable_access_logs = true

# Target groups — one per backend service
target_groups = {
  web = {
    port                  = 80
    protocol              = "HTTP"
    target_type           = "instance"
    health_check_path     = "/"
    health_check_matcher  = "200"
    healthy_threshold     = 3
    unhealthy_threshold   = 3
    health_check_interval = 30
  }
  api = {
    port                  = 8080
    protocol              = "HTTP"
    target_type           = "instance"
    health_check_path     = "/api/health"
    health_check_matcher  = "200"
    healthy_threshold     = 2
    unhealthy_threshold   = 2
    health_check_interval = 15
    health_check_timeout  = 5
  }
  static = {
    port                  = 80
    protocol              = "HTTP"
    target_type           = "ip"
    health_check_path     = "/static/health"
    health_check_matcher  = "200,301"
    stickiness_enabled    = true
    cookie_duration       = 3600
  }
}

# The default target group key — receives unmatched requests
default_target_group = "web"

# Routing rules — evaluated in priority order (lower number = higher priority)
listener_rules = {
  api_paths = {
    priority         = 10
    target_group_key = "api"
    path_patterns    = ["/api/*", "/v1/*", "/v2/*"]
  }
  static_paths = {
    priority         = 20
    target_group_key = "static"
    path_patterns    = ["/static/*", "/assets/*"]
  }
}

tags = {
  Team       = "platform"
  CostCenter = "engineering"
}
```

---

## Variables Reference

| Variable | Type | Default | Description |
|---|---|---|---|
| `aws_region` | `string` | `"us-east-1"` | AWS region to deploy into |
| `project` | `string` | — | Project name (used in resource naming and tags) |
| `environment` | `string` | — | Environment name: `dev`, `staging`, or `prod` |
| `vpc_id` | `string` | — | ID of the VPC where the ALB will be deployed |
| `subnet_ids` | `list(string)` | — | Subnet IDs for the ALB. Use public subnets for internet-facing, private subnets for internal |
| `internal` | `bool` | `false` | Set `true` to create an internal (private) ALB. Set `false` for an internet-facing ALB |
| `allowed_cidr_blocks` | `list(string)` | `["0.0.0.0/0"]` | CIDR ranges allowed to reach the ALB on ports 80 and 443 |
| `enable_deletion_protection` | `bool` | `true` | Prevent accidental deletion of the ALB |
| `idle_timeout` | `number` | `60` | Idle connection timeout in seconds (1–4000) |
| `enable_access_logs` | `bool` | `false` | Write access logs to an S3 bucket. The bucket must already exist and have the correct bucket policy |
| `https_certificate_arn` | `string` | `""` | ACM certificate ARN for the HTTPS listener. Leave empty to create an HTTP-only ALB |
| `ssl_policy` | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | SSL/TLS negotiation policy for the HTTPS listener |
| `default_target_group` | `string` | — | Key of the target group (from `target_groups`) that receives requests not matched by any listener rule |
| `target_groups` | `map(object)` | — | Map of target groups to create. Key is the logical name. See schema below |
| `listener_rules` | `map(object)` | `{}` | Map of listener rules. Key is the logical name. Rules are applied to both HTTP and HTTPS listeners. See schema below |
| `tags` | `map(string)` | `{}` | Additional tags applied to all resources |

### `target_groups` Object Schema

```hcl
target_groups = {
  "<name>" = {
    port                  = number          # Port the target listens on
    protocol              = string          # "HTTP" or "HTTPS"
    target_type           = optional(string)  # "instance" (default), "ip", or "lambda"
    healthy_threshold     = optional(number)  # Consecutive healthy checks required (default: 3)
    unhealthy_threshold   = optional(number)  # Consecutive unhealthy checks required (default: 3)
    health_check_interval = optional(number)  # Seconds between checks (default: 30)
    health_check_matcher  = optional(string)  # HTTP codes for healthy response (default: "200")
    health_check_path     = optional(string)  # Health check URL path (default: "/health")
    health_check_timeout  = optional(number)  # Seconds to wait for a response (default: 5)
    stickiness_enabled    = optional(bool)    # Enable session stickiness (default: false)
    cookie_duration       = optional(number)  # Stickiness cookie TTL in seconds (default: 86400)
  }
}
```

### `listener_rules` Object Schema

```hcl
listener_rules = {
  "<name>" = {
    priority         = number              # Rule evaluation order — lower numbers evaluated first (1–50000)
    target_group_key = string              # Must match a key in the target_groups map
    path_patterns    = optional(list(string))  # e.g., ["/api/*"]. Null to skip path matching
    host_headers     = optional(list(string))  # e.g., ["api.example.com"]. Null to skip host matching
  }
}
```

A rule can match on `path_patterns`, `host_headers`, or both (AND logic). At least one condition must be specified.

---

## Outputs Reference

| Output | Description |
|---|---|
| `alb_id` | The ID of the Application Load Balancer |
| `alb_arn` | The ARN of the Application Load Balancer |
| `alb_dns_name` | DNS name of the ALB — use this to create Route 53 alias records |
| `alb_zone_id` | Canonical hosted zone ID of the ALB (required for Route 53 alias records) |
| `security_group_id` | ID of the ALB security group (add this to allow-lists on backend resources) |
| `http_listener_arn` | ARN of the HTTP (port 80) listener |
| `https_listener_arn` | ARN of the HTTPS (port 443) listener (`null` if no certificate was provided) |
| `target_group_arns` | Map of target group name to ARN (use when registering targets from other modules) |

---

## Customization

### Setting Up HTTPS with ACM

1. Request or import a certificate in ACM:

   ```bash
   # Request a new certificate (DNS validation recommended)
   aws acm request-certificate \
     --domain-name "*.myapp.example.com" \
     --validation-method DNS \
     --region us-east-1
   ```

2. Complete DNS validation by adding the CNAME records ACM provides.

3. Pass the certificate ARN to Terraform:

   ```hcl
   https_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/..."
   ```

When `https_certificate_arn` is set, the HTTP listener automatically redirects all HTTP traffic to HTTPS (301 redirect). The HTTPS listener uses the provided certificate and the configured `ssl_policy`.

### Path-Based Routing

Route requests to different backend services based on the URL path. Useful for splitting a monolith into microservices behind a single domain.

```hcl
target_groups = {
  frontend = { port = 3000, protocol = "HTTP", target_type = "ip",       health_check_path = "/"           }
  api      = { port = 8080, protocol = "HTTP", target_type = "ip",       health_check_path = "/api/health" }
  admin    = { port = 9000, protocol = "HTTP", target_type = "instance", health_check_path = "/admin/ping" }
}

default_target_group = "frontend"

listener_rules = {
  api_rule = {
    priority         = 10
    target_group_key = "api"
    path_patterns    = ["/api/*", "/graphql"]
  }
  admin_rule = {
    priority         = 20
    target_group_key = "admin"
    path_patterns    = ["/admin/*"]
  }
}
```

### Host-Based Routing for Multiple Services

Route requests to different backends based on the `Host` header. Useful when multiple domains resolve to the same ALB.

```hcl
listener_rules = {
  api_host = {
    priority         = 10
    target_group_key = "api"
    host_headers     = ["api.myapp.example.com", "api-v2.myapp.example.com"]
  }
  admin_host = {
    priority         = 20
    target_group_key = "admin"
    host_headers     = ["admin.myapp.example.com"]
  }
}
```

Combine path and host conditions to narrow routing further:

```hcl
listener_rules = {
  api_v2 = {
    priority         = 5
    target_group_key = "api_v2"
    host_headers     = ["api.myapp.example.com"]
    path_patterns    = ["/v2/*"]
  }
}
```

### Configuring Session Stickiness

Enable sticky sessions to route a client to the same target for the duration of a session. The ALB uses an application-managed cookie.

```hcl
target_groups = {
  web = {
    port               = 80
    protocol           = "HTTP"
    stickiness_enabled = true
    cookie_duration    = 3600   # 1 hour in seconds
  }
}
```

Note: stickiness can cause uneven load distribution. Prefer stateless application architectures and external session stores (e.g., ElastiCache) where possible.

### Connecting to EC2 Target Groups

After deploying the ALB, register EC2 instances by attaching them to a target group. Add the ALB security group to the instance's inbound rules:

```hcl
# In your EC2 or security group configuration
resource "aws_security_group_rule" "allow_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = module.alb.security_group_id
  security_group_id        = aws_security_group.app.id
}
```

Reference target group ARNs from the ALB outputs when defining Auto Scaling Groups or standalone instance attachments:

```hcl
resource "aws_autoscaling_attachment" "app" {
  autoscaling_group_name = aws_autoscaling_group.app.name
  lb_target_group_arn    = module.alb.target_group_arns["web"]
}
```

### Connecting to ECS Target Groups

When using `target_type = "ip"`, ECS tasks register their IP addresses directly. Reference the target group ARN in your ECS service definition:

```hcl
resource "aws_ecs_service" "api" {
  # ...
  load_balancer {
    target_group_arn = module.alb.target_group_arns["api"]
    container_name   = "api"
    container_port   = 8080
  }

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.ecs_tasks.id]
  }
}
```

Ensure the ECS task security group allows inbound traffic from the ALB security group on the container port.

### Creating a Route 53 Alias Record

Point a custom domain at the ALB using an alias record (no TTL, no extra charge):

```hcl
resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "myapp.example.com"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
```
