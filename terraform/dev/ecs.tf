locals {
  ecs_name = lower("${var.project_name}-${var.environment}")
}

resource "aws_service_discovery_http_namespace" "service_connect" {
  name        = local.ecs_name
  description = "Service Connect namespace for ZOOP ECS services"

  tags = {
    Name = "${local.ecs_name}-service-connect"
  }
}

resource "aws_ecs_cluster" "main" {
  name = local.ecs_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.service_connect.arn
  }

  tags = {
    Name = local.ecs_name
  }
}