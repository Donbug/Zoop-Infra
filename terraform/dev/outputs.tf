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