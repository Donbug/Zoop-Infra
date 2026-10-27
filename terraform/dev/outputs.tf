output "ecr_repository_urls" {
  description = "Repository URLs for the API and AI container images"

  value = {
    for service, repository in aws_ecr_repository.service :
    service => repository.repository_url
  }
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "service_connect_namespace_id" {
  description = "Service Connect namespace ID"
  value       = aws_service_discovery_http_namespace.service_connect.id
}

output "service_connect_namespace_arn" {
  description = "Service Connect namespace ARN"
  value       = aws_service_discovery_http_namespace.service_connect.arn
}

output "ecs_log_group_names" {
  description = "CloudWatch log group names for ECS services"
  value = {
    for service, log_group in aws_cloudwatch_log_group.ecs :
    service => log_group.name
  }
}

output "api_task_execution_role_arn" {
  description = "API ECS task execution role ARN"
  value       = aws_iam_role.api_task_execution.arn
}

output "ai_task_execution_role_arn" {
  description = "AI ECS task execution role ARN"
  value       = aws_iam_role.ai_task_execution.arn
}

output "api_task_role_arn" {
  description = "API ECS task role ARN"
  value       = aws_iam_role.api_task.arn
}

output "ai_task_role_arn" {
  description = "AI ECS task role ARN"
  value       = aws_iam_role.ai_task.arn
}

output "internal_alb_arn" {
  description = "Internal API Application Load Balancer ARN"
  value       = aws_lb.api.arn
}

output "internal_alb_dns_name" {
  description = "Internal API Application Load Balancer DNS name"
  value       = aws_lb.api.dns_name
}

output "api_target_group_arn" {
  description = "API target group ARN"
  value       = aws_lb_target_group.api.arn
}

output "api_http_listener_arn" {
  description = "API HTTP listener ARN"
  value       = aws_lb_listener.http.arn
}

output "rds_postgres_endpoint" {
  description = "RDS PostgreSQL connection endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_postgres_address" {
  description = "RDS PostgreSQL hostname"
  value       = aws_db_instance.postgres.address
}

output "rds_postgres_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.postgres.port
}

output "rds_postgres_database_name" {
  description = "Initial PostgreSQL database name"
  value       = aws_db_instance.postgres.db_name
}

output "rds_postgres_secret_arn" {
  description = "Secrets Manager ARN containing the RDS master credentials"
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

output "valkey_primary_endpoint" {
  description = "ElastiCache Valkey primary endpoint"
  value       = aws_elasticache_replication_group.valkey.primary_endpoint_address
}

output "valkey_port" {
  description = "ElastiCache Valkey port"
  value       = aws_elasticache_replication_group.valkey.port
}

output "valkey_replication_group_arn" {
  description = "ElastiCache Valkey replication group ARN"
  value       = aws_elasticache_replication_group.valkey.arn
}

output "neo4j_instance_id" {
  description = "Neo4j EC2 instance ID"
  value       = aws_instance.neo4j.id
}

output "neo4j_private_ip" {
  description = "Neo4j EC2 private IP address"
  value       = aws_instance.neo4j.private_ip
}

output "neo4j_data_volume_id" {
  description = "Neo4j data EBS volume ID"
  value       = aws_ebs_volume.neo4j_data.id
}

output "neo4j_ssm_role_arn" {
  description = "Neo4j EC2 SSM IAM role ARN"
  value       = aws_iam_role.neo4j_ssm.arn
}

# ECS Task Definitions
output "api_task_definition_arn" {
  description = "ARN of the API ECS task definition"
  value       = aws_ecs_task_definition.api.arn
}

output "ai_task_definition_arn" {
  description = "ARN of the AI ECS task definition"
  value       = aws_ecs_task_definition.ai.arn
}

# ECS Services
output "api_ecs_service_name" {
  description = "Name of the API ECS service"
  value       = aws_ecs_service.api.name
}

output "ai_ecs_service_name" {
  description = "Name of the AI ECS service"
  value       = aws_ecs_service.ai.name
}

output "ai_service_connect_endpoint" {
  description = "Internal Service Connect endpoint for the AI service"
  value       = "ai:${var.ai_container_port}"
}

# CloudFront VPC Origin
output "cloudfront_vpc_origin_id" {
  description = "ID of the CloudFront VPC origin for the internal ALB"
  value       = aws_cloudfront_vpc_origin.api.id
}

# CloudFront Distribution
output "cloudfront_distribution_id" {
  description = "ID of the API CloudFront distribution"
  value       = aws_cloudfront_distribution.api.id
}

output "cloudfront_domain_name" {
  description = "Domain name of the API CloudFront distribution"
  value       = aws_cloudfront_distribution.api.domain_name
}

output "cloudfront_api_url" {
  description = "HTTPS URL of the shared web and API CloudFront distribution"
  value       = "https://${aws_cloudfront_distribution.api.domain_name}"
}

output "web_bucket_name" {
  description = "Private S3 bucket containing the dev web application"
  value       = aws_s3_bucket.web.id
}

output "web_bucket_arn" {
  description = "ARN of the private dev web application bucket"
  value       = aws_s3_bucket.web.arn
}

output "web_url" {
  description = "CloudFront URL for the dev web application"
  value       = "https://${aws_cloudfront_distribution.api.domain_name}"
}
