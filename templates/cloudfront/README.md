# CloudFront Terraform Template

## Overview

This template provisions a CloudFront distribution with support for S3 static site hosting or ALB/API backend origins, custom domains, WAF protection, and advanced caching configuration.

**Resources created:**

- **CloudFront Distribution** with configurable price class and HTTPS enforcement
- **Origin Access Control (OAC)** — secure S3 access without making the bucket public (replaces legacy OAI)
- **Custom Origins** — supports ALB, API Gateway, or any HTTP/HTTPS endpoint
- **Cache Policy** — use AWS-managed policies or create a custom policy with configurable TTLs and cache keys
- **Ordered Cache Behaviors** — route different URL paths to different origins
- **CloudFront Function** — lightweight edge function for viewer request manipulation (URL rewrites, header injection)
- **WAF Integration** — attach an AWS WAF Web ACL for DDoS protection and request filtering
- **Geo-Restriction** — allow or block specific countries
- **Access Logging** — S3 bucket for CloudFront access logs (created automatically when enabled)

---

## Quick Start

### S3 Static Site

```hcl
module "cdn" {
  source = "../cloudfront"

  project     = "myapp"
  environment = "prod"

  s3_origin_bucket  = "myapp-prod-static"
  s3_origin_region  = "us-east-1"
  default_origin_id = "s3-static"

  default_root_object = "index.html"

  # Custom domain with ACM certificate
  domain_aliases      = ["www.example.com", "example.com"]
  acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc-123"

  enable_logging = true

  tags = {
    Team = "frontend"
  }
}
```

### ALB Backend with API Path Routing

```hcl
module "cdn" {
  source = "../cloudfront"

  project     = "myapp"
  environment = "prod"

  custom_origins = {
    alb-api = {
      domain_name     = "myapp-alb-123456.us-east-1.elb.amazonaws.com"
      protocol_policy = "https-only"
      custom_headers  = {
        "X-Origin-Verify" = "my-secret-token"
      }
    }
    s3-assets = {
      domain_name     = "myapp-prod-assets.s3-website.us-east-1.amazonaws.com"
      http_port       = 80
      protocol_policy = "http-only"
    }
  }

  default_origin_id      = "alb-api"
  default_allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]

  ordered_cache_behaviors = [
    {
      path_pattern    = "/assets/*"
      origin_id       = "s3-assets"
      allowed_methods = ["GET", "HEAD"]
      cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"  # CachingOptimized
    }
  ]

  domain_aliases      = ["api.example.com"]
  acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/def-456"

  waf_web_acl_arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/myapp-waf/abc"

  tags = {
    Team = "platform"
  }
}
```

### terraform.tfvars Example

```hcl
project     = "myapp"
environment = "prod"

s3_origin_bucket  = "myapp-prod-website"
s3_origin_region  = "us-east-1"
default_origin_id = "s3-static"

default_root_object = "index.html"
price_class         = "PriceClass_100"

domain_aliases      = ["www.example.com"]
acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc-123"

enable_logging = true

geo_restriction_type      = "none"
geo_restriction_locations = []

tags = {
  Environment = "prod"
  Team        = "frontend"
}
```

---

## Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project` | `string` | — | Project name |
| `environment` | `string` | — | Environment: dev, staging, or prod |
| `s3_origin_bucket` | `string` | `""` | S3 bucket name for S3 origin; leave empty for no S3 origin |
| `s3_origin_region` | `string` | `"us-east-1"` | Region of the S3 bucket origin |
| `custom_origins` | `map(object)` | `{}` | Map of custom ALB/API origins (domain\_name, ports, protocol, custom headers) |
| `default_origin_id` | `string` | — | Origin ID to use for the default cache behavior |
| `default_root_object` | `string` | `"index.html"` | Default root object served at the distribution root |
| `default_allowed_methods` | `list(string)` | `["GET","HEAD","OPTIONS"]` | HTTP methods allowed on the default behavior |
| `price_class` | `string` | `"PriceClass_100"` | `PriceClass_All`, `PriceClass_200` (no South America/Australia), or `PriceClass_100` (US/EU only) |
| `domain_aliases` | `list(string)` | `[]` | Custom domain aliases; requires `acm_certificate_arn` |
| `acm_certificate_arn` | `string` | `""` | ACM certificate ARN (must be in `us-east-1`) |
| `waf_web_acl_arn` | `string` | `""` | WAF Web ACL ARN (must be CLOUDFRONT scope, in `us-east-1`) |
| `create_custom_cache_policy` | `bool` | `false` | Create a custom cache policy (overrides `cache_policy_id`) |
| `cache_policy_id` | `string` | CachingOptimized | Managed cache policy ID when not using a custom policy |
| `cache_default_ttl` | `number` | `86400` | Default TTL in seconds for custom cache policy |
| `cache_max_ttl` | `number` | `31536000` | Maximum TTL in seconds for custom cache policy |
| `cache_query_strings` | `bool` | `false` | Include query strings in the cache key |
| `origin_request_policy_id` | `string` | `""` | Managed origin request policy ID |
| `viewer_request_function_arn` | `string` | `""` | ARN of a CloudFront Function to run on viewer requests |
| `ordered_cache_behaviors` | `list(object)` | `[]` | Additional path-based cache behaviors with their origin and policy |
| `geo_restriction_type` | `string` | `"none"` | `none`, `whitelist`, or `blacklist` |
| `geo_restriction_locations` | `list(string)` | `[]` | ISO 3166-1-alpha-2 country codes for geo restriction |
| `enable_logging` | `bool` | `false` | Enable CloudFront access logging to a new S3 bucket |
| `tags` | `map(string)` | `{}` | Tags applied to all resources |

---

## Outputs

| Name | Description |
|------|-------------|
| `distribution_id` | The CloudFront distribution ID |
| `distribution_arn` | The ARN of the CloudFront distribution |
| `domain_name` | CloudFront distribution domain name (e.g., `d1abc.cloudfront.net`) |
| `hosted_zone_id` | Hosted zone ID for use in Route53 alias records |
| `origin_access_control_id` | OAC ID to reference in S3 bucket policies |
| `log_bucket_id` | ID of the access log S3 bucket (null if logging disabled) |

---

## Customization

### Adding a Custom Domain and ACM Certificate

CloudFront requires the ACM certificate to be in `us-east-1` regardless of where your resources are deployed.

1. Create the certificate (see the Route53 template for DNS validation):

```hcl
module "cert" {
  source = "../route53"
  providers = { aws = aws.us_east_1 }

  domain_name            = "example.com"
  create_zone            = false
  create_acm_certificate = true
  certificate_san        = ["www.example.com", "*.example.com"]
}
```

2. Reference it in CloudFront:

```hcl
domain_aliases      = ["www.example.com", "example.com"]
acm_certificate_arn = module.cert.acm_certificate_arn
```

### Path-Based Routing to Multiple Origins

Route different URL prefixes to different backends using `ordered_cache_behaviors`. Behaviors are evaluated in list order; the default behavior is the fallback.

```hcl
custom_origins = {
  api = { domain_name = "api-alb.example.com", protocol_policy = "https-only" }
  cdn = { domain_name = "assets.example.com",  protocol_policy = "https-only" }
}

default_origin_id = "api"

ordered_cache_behaviors = [
  {
    path_pattern    = "/static/*"
    origin_id       = "cdn"
    allowed_methods = ["GET", "HEAD"]
    # CachingOptimized managed policy
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  },
  {
    path_pattern    = "/api/*"
    origin_id       = "api"
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    # CachingDisabled managed policy
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  }
]
```

### Cache Invalidation After Deployment

Invalidate cached objects after deploying new static assets. This can be run from a CI/CD pipeline:

```bash
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw distribution_id) \
  --paths "/*"
```

For targeted invalidations (faster and cheaper than `/*`):

```bash
aws cloudfront create-invalidation \
  --distribution-id E1ABCDEF123456 \
  --paths "/index.html" "/app.*.js" "/app.*.css"
```

As a Terraform null\_resource for automated invalidations after S3 uploads:

```hcl
resource "null_resource" "invalidate" {
  triggers = { deploy_time = timestamp() }

  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${module.cdn.distribution_id} --paths '/*'"
  }
}
```

### WAF Integration

Attach a WAF Web ACL (must use CLOUDFRONT scope, created in us-east-1) for request filtering:

```hcl
waf_web_acl_arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/myapp-prod/abc123"
```

WAF can block bad bots, SQL injection, XSS, and rate-limit abusive IPs without changes to your application.

### Geo-Restriction

Block or allow traffic from specific countries:

```hcl
# Whitelist: only allow these countries
geo_restriction_type      = "whitelist"
geo_restriction_locations = ["US", "CA", "GB", "DE", "FR"]

# Blacklist: block specific countries
geo_restriction_type      = "blacklist"
geo_restriction_locations = ["KP", "IR"]
```

Use ISO 3166-1-alpha-2 country codes. Geo-restriction is approximate and should not be used as the sole security control.
