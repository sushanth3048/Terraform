# Route53 Terraform Template

## Overview

This template manages DNS for a domain hosted on Route53. It can create a new hosted zone or reference an existing one, and supports all common record types plus health checks and ACM certificate provisioning with automatic DNS validation.

**Resources created:**

- **Hosted Zone** (new or data-source lookup of existing) — public or private
- **DNS Records** — A, AAAA, CNAME, MX, TXT, and alias records (for ALB, CloudFront, API Gateway, etc.)
- **Weighted, Failover, and Latency Routing Policies** — configurable per record
- **Route53 Health Checks** — HTTP/HTTPS/TCP endpoint monitoring
- **ACM Certificate** — with DNS validation records automatically created in the hosted zone
- **ACM Certificate Validation** — waits for certificate issuance before completing

---

## Quick Start

### Domain Setup with ALB Alias Record and ACM Certificate

```hcl
module "dns" {
  source = "../route53"

  project     = "myapp"
  environment = "prod"
  aws_region  = "us-east-1"

  domain_name  = "example.com"
  create_zone  = true

  records = {
    root_alias = {
      name = ""
      type = "A"
      alias = {
        name    = module.alb.dns_name
        zone_id = module.alb.zone_id
        evaluate_target_health = true
      }
    }
    www_alias = {
      name = "www"
      type = "A"
      alias = {
        name    = module.alb.dns_name
        zone_id = module.alb.zone_id
        evaluate_target_health = true
      }
    }
    mx_records = {
      name    = ""
      type    = "MX"
      ttl     = 3600
      records = [
        "10 mail1.example.com.",
        "20 mail2.example.com."
      ]
    }
    spf = {
      name    = ""
      type    = "TXT"
      ttl     = 300
      records = ["v=spf1 include:_spf.google.com ~all"]
    }
  }

  create_acm_certificate = true
  certificate_san        = ["www.example.com", "api.example.com"]

  tags = {
    Team = "platform"
  }
}
```

### Private Hosted Zone for Internal DNS

```hcl
module "internal_dns" {
  source = "../route53"

  project     = "myapp"
  environment = "prod"

  domain_name          = "internal.example.com"
  create_zone          = true
  private_zone         = true
  private_zone_vpc_ids = [module.vpc.vpc_id]

  records = {
    db = {
      name    = "db"
      type    = "CNAME"
      ttl     = 60
      records = [module.rds.endpoint]
    }
    cache = {
      name    = "cache"
      type    = "CNAME"
      ttl     = 60
      records = [module.elasticache.redis_primary_endpoint]
    }
  }

  tags = {
    Purpose = "internal-dns"
  }
}
```

### terraform.tfvars Example

```hcl
project     = "myapp"
environment = "prod"
aws_region  = "us-east-1"

domain_name = "example.com"
create_zone = true

records = {
  api_alias = {
    name = "api"
    type = "A"
    alias = {
      name    = "myapp-alb-123456.us-east-1.elb.amazonaws.com"
      zone_id = "Z35SXDOTRQ7X7K"
      evaluate_target_health = true
    }
  }
}

create_acm_certificate = true
certificate_san        = ["*.example.com"]

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
| `domain_name` | `string` | — | Apex domain name (e.g., `example.com`) |
| `create_zone` | `bool` | `true` | Create a new hosted zone; set to `false` to look up an existing zone |
| `private_zone` | `bool` | `false` | Create a private hosted zone (requires `private_zone_vpc_ids`) |
| `private_zone_vpc_ids` | `list(string)` | `[]` | VPC IDs to associate with the private hosted zone |
| `records` | `map(object)` | `{}` | DNS records to create (see schema below) |
| `health_checks` | `map(object)` | `{}` | Route53 health checks to create |
| `create_acm_certificate` | `bool` | `false` | Create an ACM certificate and validate it via DNS |
| `certificate_san` | `list(string)` | `[]` | Subject Alternative Names for the ACM certificate |
| `tags` | `map(string)` | `{}` | Tags applied to all resources |

**`records` object schema:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | `string` | — | DNS record name (relative to zone; use `""` for apex) |
| `type` | `string` | — | Record type: `A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS`, `SRV`, etc. |
| `ttl` | `number` | `300` | Record TTL in seconds (ignored for alias records) |
| `records` | `list(string)` | `null` | Record values (not used for alias records) |
| `alias` | `object` | `null` | Alias target: `{name, zone_id, evaluate_target_health}` |
| `weight` | `number` | `null` | Routing weight for weighted policy |
| `failover` | `string` | `null` | `PRIMARY` or `SECONDARY` for failover routing |
| `set_identifier` | `string` | `null` | Unique identifier required for weighted/failover/latency records |
| `health_check_key` | `string` | `null` | Key of a `health_checks` entry to associate with this record |

**`health_checks` object schema:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `type` | `string` | — | `HTTP`, `HTTPS`, `HTTP_STR_MATCH`, `HTTPS_STR_MATCH`, or `TCP` |
| `fqdn` | `string` | `null` | Fully qualified domain name of the endpoint to check |
| `ip_address` | `string` | `null` | IP address of the endpoint (alternative to `fqdn`) |
| `port` | `number` | `443` | Port to check |
| `resource_path` | `string` | `"/"` | URL path for HTTP/HTTPS checks |
| `failure_threshold` | `number` | `3` | Consecutive failures before marking unhealthy |
| `request_interval` | `number` | `30` | Seconds between health check requests (10 or 30) |
| `enable_sni` | `bool` | `true` | Enable SNI for HTTPS checks |

---

## Outputs

| Name | Description |
|------|-------------|
| `zone_id` | The hosted zone ID |
| `zone_name_servers` | Name servers for the zone (use to delegate from registrar; null for existing zones) |
| `record_fqdns` | Map of record key to fully qualified domain name |
| `acm_certificate_arn` | ARN of the ACM certificate (null if not created) |
| `acm_certificate_status` | `ISSUED` once the certificate is validated (null if not created) |

---

## Customization

### Alias Records for ALB and CloudFront

Use alias records (not CNAME) for AWS resources. Alias records are free, support the zone apex (bare domain), and have health-check-aware routing.

**ALB alias:**
```hcl
records = {
  www = {
    name = "www"
    type = "A"
    alias = {
      name    = module.alb.dns_name
      zone_id = module.alb.zone_id
      evaluate_target_health = true
    }
  }
}
```

**CloudFront alias:**
```hcl
records = {
  cdn = {
    name = ""
    type = "A"
    alias = {
      name    = module.cloudfront.domain_name
      zone_id = module.cloudfront.hosted_zone_id  # always Z2FDTNDATAQYW2
      evaluate_target_health = false
    }
  }
}
```

### Weighted Routing for Blue-Green Deployments

Split traffic between two ALBs during a blue-green deployment:

```hcl
records = {
  api_blue = {
    name           = "api"
    type           = "A"
    set_identifier = "blue"
    weight         = 90
    alias = {
      name    = "blue-alb.us-east-1.elb.amazonaws.com"
      zone_id = "Z35SXDOTRQ7X7K"
      evaluate_target_health = true
    }
  }
  api_green = {
    name           = "api"
    type           = "A"
    set_identifier = "green"
    weight         = 10
    alias = {
      name    = "green-alb.us-east-1.elb.amazonaws.com"
      zone_id = "Z35SXDOTRQ7X7K"
      evaluate_target_health = true
    }
  }
}
```

Gradually shift weight from 90/10 to 0/100 during the rollout. Set `weight = 0` (not remove) to stop routing to the old stack while keeping the record.

### Failover Routing

Route to a secondary region when the primary fails:

```hcl
health_checks = {
  primary_health = {
    type          = "HTTPS"
    fqdn          = "primary-alb.us-east-1.elb.amazonaws.com"
    resource_path = "/health"
    port          = 443
  }
}

records = {
  api_primary = {
    name             = "api"
    type             = "A"
    set_identifier   = "primary"
    failover         = "PRIMARY"
    health_check_key = "primary_health"
    alias = {
      name    = "primary-alb.us-east-1.elb.amazonaws.com"
      zone_id = "Z35SXDOTRQ7X7K"
      evaluate_target_health = true
    }
  }
  api_secondary = {
    name           = "api"
    type           = "A"
    set_identifier = "secondary"
    failover       = "SECONDARY"
    alias = {
      name    = "secondary-alb.eu-west-1.elb.amazonaws.com"
      zone_id = "Z32O12XQLNTSW2"
      evaluate_target_health = false
    }
  }
}
```

Route53 monitors the primary health check and automatically fails over when the threshold is reached.

### ACM Certificate with DNS Validation

Set `create_acm_certificate = true` to provision a certificate and automatically create the required CNAME validation records in the hosted zone.

```hcl
create_acm_certificate = true
certificate_san        = ["www.example.com", "*.example.com"]
```

The certificate ARN is output as `acm_certificate_arn` and can be passed directly to the CloudFront or ALB template.

**Note:** For CloudFront, the certificate must exist in `us-east-1`. Use a provider alias if your main region is different:

```hcl
module "cert" {
  source    = "../route53"
  providers = { aws = aws.us_east_1 }

  domain_name            = "example.com"
  create_zone            = false  # reference existing zone
  create_acm_certificate = true
  certificate_san        = ["*.example.com"]
}
```

### Delegating Subdomains

To delegate `services.example.com` to a separate hosted zone (e.g., per-team or per-environment):

1. Create the child zone separately and capture its name servers.
2. Add an NS record in the parent zone pointing to the child zone's name servers:

```hcl
records = {
  services_ns = {
    name    = "services"
    type    = "NS"
    ttl     = 3600
    records = [
      "ns-1234.awsdns-12.org.",
      "ns-5678.awsdns-34.co.uk.",
      "ns-90.awsdns-56.com.",
      "ns-12.awsdns-78.net."
    ]
  }
}
```

### Private Hosted Zones for Internal DNS

Private hosted zones resolve only within associated VPCs, keeping internal service discovery off the public internet:

```hcl
domain_name          = "internal.myapp.local"
create_zone          = true
private_zone         = true
private_zone_vpc_ids = ["vpc-0abc123", "vpc-0def456"]

records = {
  rds_primary = {
    name    = "postgres"
    type    = "CNAME"
    ttl     = 60
    records = ["myapp-prod.cluster-xyz.us-east-1.rds.amazonaws.com"]
  }
}
```

Applications reference `postgres.internal.myapp.local` rather than hardcoding RDS endpoints. When you swap the database, update only the DNS record.
