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

resource "aws_service_discovery_private_dns_namespace" "ai_private" {
  name        = "${local.ecs_name}.internal"
  description = "Private DNS namespace for ZOOP AI service discovery"
  vpc         = aws_vpc.main.id

  tags = {
    Name    = "${local.ecs_name}-ai-private-dns"
    Service = "ai"
  }
}

resource "aws_service_discovery_service" "ai_private" {
  name = "ai"

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.ai_private.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
  }

  tags = {
    Name    = "${local.ecs_name}-ai-private-dns"
    Service = "ai"
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