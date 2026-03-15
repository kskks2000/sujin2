output "backend_ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "backend_alb_dns_name" {
  value = aws_lb.api.dns_name
}

output "postgres_address" {
  value = aws_db_instance.postgres.address
}

output "redis_address" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}
