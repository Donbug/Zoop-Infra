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

output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "api_task_role_arn" {
  description = "API ECS task role ARN"
  value       = aws_iam_role.api_task.arn
}

output "ai_task_role_arn" {
  description = "AI ECS task role ARN"
  value       = aws_iam_role.ai_task.arn
}