output "redis_primary_endpoint" {
  description = "Primary endpoint for Redis (non-cluster mode)"
  value       = try(aws_elasticache_replication_group.redis[0].primary_endpoint_address, null)
}

output "redis_reader_endpoint" {
  description = "Reader endpoint for Redis replicas"
  value       = try(aws_elasticache_replication_group.redis[0].reader_endpoint_address, null)
}

output "redis_cluster_enabled_endpoints" {
  description = "Configuration endpoint for Redis cluster mode"
  value       = try(aws_elasticache_replication_group.redis[0].configuration_endpoint_address, null)
}

output "memcached_endpoints" {
  description = "List of cache node endpoints for Memcached"
  value       = try(aws_elasticache_cluster.memcached[0].cache_nodes[*].address, null)
}

output "port" {
  description = "Cache port"
  value       = var.engine == "redis" ? 6379 : 11211
}

output "security_group_id" {
  description = "The ID of the ElastiCache security group"
  value       = aws_security_group.elasticache.id
}

output "subnet_group_name" {
  description = "The name of the ElastiCache subnet group"
  value       = aws_elasticache_subnet_group.main.name
}

output "replication_group_id" {
  description = "The ID of the Redis replication group (if Redis)"
  value       = try(aws_elasticache_replication_group.redis[0].id, null)
}
