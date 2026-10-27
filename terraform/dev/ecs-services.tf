locals {
  api_container_name = "api"
  ai_container_name  = "ai"
}

# API Task Definition
resource "aws_ecs_task_definition" "api" {
  family                   = "${local.ecs_name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.api_task_cpu)
  memory                   = tostring(var.api_task_memory)
  execution_role_arn       = aws_iam_role.api_task_execution.arn
  task_role_arn            = aws_iam_role.api_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = local.api_container_name
      image     = "${aws_ecr_repository.service["api"].repository_url}:${var.api_image_tag}"
      essential = true

      portMappings = [
        {
          name          = "api-http"
          containerPort = var.api_container_port
          hostPort      = var.api_container_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      environment = [
        {
          name  = "SERVER_PORT"
          value = tostring(var.api_container_port)
        },
        {
          name  = "DB_URL"
          value = "jdbc:postgresql://${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.rds_database_name}"
        },
        {
          name  = "ZOOP_AUTH_CSRF_ACTIVE_KEY_ID"
          value = "dev-v1"
        },
        {
          name  = "ZOOP_API_CORS_ALLOWED_ORIGINS"
          value = "https://localhost:5194"
        },
        {
          name  = "ZOOP_AUTH_ALLOWED_ORIGINS"
          value = "https://localhost:5194"
        },
        {
          name  = "ZOOP_AI_CLIENT_ENABLED"
          value = "false"
        },
        {
          name  = "ZOOP_AI_CHAT_CLIENT_ENABLED"
          value = "false"
        },
        {
          name  = "ZOOP_AI_EXTRACTION_CLIENT_ENABLED"
          value = "false"
        },
        {
          name  = "ZOOP_AI_RELATION_CLIENT_ENABLED"
          value = "false"
        }
      ]

      secrets = [
        {
          name      = "DB_USERNAME"
          valueFrom = "${aws_db_instance.postgres.master_user_secret[0].secret_arn}:username::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_db_instance.postgres.master_user_secret[0].secret_arn}:password::"
        },
        {
          name      = "ZOOP_AUTH_CSRF_KEYS"
          valueFrom = aws_secretsmanager_secret.api_csrf.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs["api"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }
    }
  ])

  depends_on = [
    aws_iam_role_policy.api_runtime_secret_access,
    aws_secretsmanager_secret_version.api_csrf
  ]

  tags = {
    Name    = "${local.ecs_name}-api"
    Service = "api"
  }
}

# AI Task Definition
resource "aws_ecs_task_definition" "ai" {
  family                   = "${local.ecs_name}-ai"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.ai_task_cpu)
  memory                   = tostring(var.ai_task_memory)
  execution_role_arn       = aws_iam_role.ai_task_execution.arn
  task_role_arn            = aws_iam_role.ai_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = local.ai_container_name
      image     = "${aws_ecr_repository.service["ai"].repository_url}:${var.ai_image_tag}"
      essential = true

      portMappings = [
        {
          name          = "ai-http"
          containerPort = var.ai_container_port
          hostPort      = var.ai_container_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs["ai"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ai"
        }
      }
    }
  ])

  tags = {
    Name    = "${local.ecs_name}-ai"
    Service = "ai"
  }
}

# API ECS Service
resource "aws_ecs_service" "api" {
  name             = "${local.ecs_name}-api"
  cluster          = aws_ecs_cluster.main.id
  task_definition  = aws_ecs_task_definition.api.arn
  desired_count    = var.api_desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  enable_execute_command = true
  propagate_tags         = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets = [
      aws_subnet.private_app_a.id,
      aws_subnet.private_app_c.id
    ]

    security_groups  = [aws_security_group.api.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = local.api_container_name
    container_port   = var.api_container_port
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.service_connect.arn
  }

  depends_on = [
    aws_lb_listener.http
  ]

  tags = {
    Name    = "${local.ecs_name}-api"
    Service = "api"
  }
}

# AI ECS Service
resource "aws_ecs_service" "ai" {
  name             = "${local.ecs_name}-ai"
  cluster          = aws_ecs_cluster.main.id
  task_definition  = aws_ecs_task_definition.ai.arn
  desired_count    = var.ai_desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  enable_execute_command = true
  propagate_tags         = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets = [
      aws_subnet.private_app_a.id,
      aws_subnet.private_app_c.id
    ]

    security_groups  = [aws_security_group.ai.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.service_connect.arn

    service {
      port_name      = "ai-http"
      discovery_name = "ai"

      client_alias {
        dns_name = "ai"
        port     = var.ai_container_port
      }
    }
  }

  tags = {
    Name    = "${local.ecs_name}-ai"
    Service = "ai"
  }
}