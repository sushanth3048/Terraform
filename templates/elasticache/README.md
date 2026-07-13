# ElastiCache Terraform Template

## Overview

This template provisions a managed caching layer using either Redis or Memcached. Both engines are supported with a single, unified variable interface.

**Resources created:**

- **Security Group** — controls inbound access to cache nodes from your application
- **ElastiCache Subnet Group** — places nodes in your designated private subnets
- **Parameter Group** — custom engine parameters (e.g., `maxmemory-policy`, `timeout`)
- **Redis Replication Group** (when `engine = "redis"`) — supports single-node, primary/replica, or cluster mode (sharding)
- **Memcached Cluster** (when `engine = "memcached"`) — multi-node horizontal scaling

---

## Quick Start

### Redis (Single Node — Development)

```hcl
module "cache" {
  source = "../elasticache"

  project     = "myapp"
  environment = "dev"
  aws_region  = "us-east-1"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  engine         = "redis"
  engine_version = "7.1"
  node_type      = "cache.t3.micro"
  num_cache_nodes = 1

  allowed_security_group_ids = [module.ecs.security_group_id]

  tags = {
    Team = "platform"
  }
}
```

### Redis (Multi-AZ with Replicas — Production)

```hcl
module "cache" {
  source = "../elasticache"

  project     = "myapp"
  environment = "prod"
  aws_region  = "us-east-1"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  engine         = "redis"
  engine_version = "7.1"
  node_type      = "cache.r7g.large"
  num_cache_nodes = 3  # 1 primary + 2 replicas

  multi_az_enabled = true

  snapshot_retention_limit = 7
  snapshot_window          = "03:00-04:00"
  maintenance_window       = "sun:04:00-sun:05:00"

  allowed_security_group_ids = [module.ecs.security_group_id]

  tags = {
    CostCenter = "platform"
  }
}
```

### Memcached Cluster

```hcl
module "cache" {
  source = "../elasticache"

  project     = "myapp"
  environment = "prod"
  aws_region  = "us-east-1"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  engine                  = "memcached"
  engine_version          = "1.6.22"
  parameter_group_family  = "memcached1.6"
  node_type               = "cache.m6g.large"
  num_cache_nodes         = 3

  allowed_security_group_ids = [module.ecs.security_group_id]

  tags = {
    Team = "platform"
  }
}
```

### terraform.tfvars Example

```hcl
project     = "myapp"
environment = "prod"
aws_region  = "us-east-1"

vpc_id     = "vpc-0abc123def456789"
subnet_ids = ["subnet-0aaa111", "subnet-0bbb222", "subnet-0ccc333"]

engine         = "redis"
engine_version = "7.1"
node_type      = "cache.r7g.large"
num_cache_nodes = 2

multi_az_enabled         = true
snapshot_retention_limit = 7
snapshot_window          = "03:00-04:00"
maintenance_window       = "sun:04:00-sun:05:00"

allowed_security_group_ids = ["sg-0app123"]

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
| `vpc_id` | `string` | — | VPC ID for the ElastiCache cluster |
| `subnet_ids` | `list(string)` | — | Private subnet IDs for the subnet group |
| `engine` | `string` | `"redis"` | Cache engine: `redis` or `memcached` |
| `engine_version` | `string` | `"7.1"` | Engine version (e.g., `7.1` for Redis, `1.6.22` for Memcached) |
| `node_type` | `string` | `"cache.t3.micro"` | ElastiCache node type |
| `num_cache_nodes` | `number` | `1` | Number of nodes (Redis: 1 primary + N-1 replicas; Memcached: total nodes) |
| `multi_az_enabled` | `bool` | `false` | Enable Multi-AZ automatic failover (Redis replication groups only) |
| `cluster_mode_enabled` | `bool` | `false` | Enable Redis cluster mode (sharding across multiple node groups) |
| `num_node_groups` | `number` | `1` | Number of shards (Redis cluster mode only) |
| `replicas_per_node_group` | `number` | `1` | Replicas per shard (Redis cluster mode only) |
| `auth_token` | `string` | `""` | Redis AUTH token for in-transit encryption; leave empty to auto-generate |
| `parameter_group_family` | `string` | `"redis7"` | Parameter group family (`redis7`, `memcached1.6`, etc.) |
| `cache_parameters` | `list(object)` | `[]` | Custom engine parameters (list of `{name, value}` objects) |
| `snapshot_retention_limit` | `number` | `1` | Days to retain automatic snapshots (Redis only; 0 = disabled) |
| `snapshot_window` | `string` | `"05:00-06:00"` | Daily snapshot window in UTC (Redis only) |
| `maintenance_window` | `string` | `"sun:06:00-sun:07:00"` | Weekly maintenance window |
| `apply_immediately` | `bool` | `false` | Apply parameter changes immediately (may cause brief downtime) |
| `allowed_cidr_blocks` | `list(string)` | `[]` | CIDR blocks allowed to connect to the cache |
| `allowed_security_group_ids` | `list(string)` | `[]` | Security group IDs allowed to connect to the cache |
| `tags` | `map(string)` | `{}` | Tags applied to all resources |

---

## Outputs

| Name | Description |
|------|-------------|
| `redis_primary_endpoint` | Primary endpoint for Redis writes (non-cluster mode) |
| `redis_reader_endpoint` | Reader endpoint for Redis read replicas (non-cluster mode) |
| `redis_cluster_enabled_endpoints` | Configuration endpoint for Redis cluster mode |
| `memcached_endpoints` | List of node addresses for Memcached clusters |
| `port` | Cache port (6379 for Redis, 11211 for Memcached) |
| `security_group_id` | Security group ID attached to the cache cluster |
| `subnet_group_name` | Name of the ElastiCache subnet group |
| `replication_group_id` | ID of the Redis replication group (null for Memcached) |

---

## Customization

### Redis Cluster Mode for Sharding

Cluster mode distributes data across multiple shards (node groups), each with its own primary and replicas. This enables horizontal scaling beyond a single node's memory limit.

```hcl
engine              = "redis"
cluster_mode_enabled = true
num_node_groups     = 3   # 3 shards
replicas_per_node_group = 1  # 1 replica per shard = 6 total nodes

node_type = "cache.r7g.xlarge"
```

Your application must use a Redis cluster-aware client (e.g., `redis-py-cluster`, `ioredis` in cluster mode). Connect via the `redis_cluster_enabled_endpoints` output.

### Multi-AZ Failover

Enable automatic failover so a read replica is promoted if the primary node fails:

```hcl
num_cache_nodes  = 2  # at least 1 replica required
multi_az_enabled = true
```

Redis replication groups with Multi-AZ failover typically recover in under 60 seconds.

### Redis AUTH Token

Require a password for all Redis connections (in-transit encryption is automatically enabled when an AUTH token is set):

```hcl
auth_token = "my-long-random-secret-token-here"
```

Store the token in Secrets Manager and reference it in your application rather than hardcoding it in tfvars.

### Snapshot Retention

Configure how many days of automatic daily snapshots to keep:

```hcl
snapshot_retention_limit = 7      # keep 7 days of snapshots
snapshot_window          = "02:00-03:00"  # low-traffic window
```

Set `snapshot_retention_limit = 0` to disable automatic snapshots (not recommended for production).

### Choosing the Right Node Type

| Use Case | Recommended Node Type |
|----------|----------------------|
| Development / testing | `cache.t3.micro` or `cache.t3.small` |
| Small production workload | `cache.t3.medium` |
| Session store / API cache | `cache.m6g.large` |
| Large dataset in-memory | `cache.r7g.xlarge` or higher |
| High-throughput session cache | `cache.m6g.2xlarge` |

Graviton-based nodes (`m6g`, `r7g`) offer the best price/performance ratio. The `t3` family is burstable and suitable for development.

### Custom Engine Parameters

Tune Redis or Memcached behaviour via `cache_parameters`:

```hcl
cache_parameters = [
  {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  },
  {
    name  = "timeout"
    value = "300"
  }
]
```

Common Redis policies: `allkeys-lru` (evict any key by LRU), `volatile-lru` (evict only keys with TTL), `noeviction` (return error when full).
