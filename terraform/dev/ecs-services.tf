locals {
  api_container_name = "api"
  ai_container_name  = "ai"

  api_cors_allowed_origins = [
    "https://dwihu34r1u7th.cloudfront.net",
    "https://localhost:5194",
    "http://localhost:5173",
    "http://127.0.0.1:5173",
    "http://[::1]:5173",
  ]

  api_auth_allowed_origins = [
    "https://dwihu34r1u7th.cloudfront.net",
    "https://localhost:5194",
  ]
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
          value = join(",", local.api_cors_allowed_origins)
        },
        {
          name  = "ZOOP_AUTH_ALLOWED_ORIGINS"
          value = join(",", local.api_auth_allowed_origins)
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
        },
        {
          name      = "ZOOP_AUTH_SOCIAL_GOOGLE_CLIENT_ID"
          valueFrom = "${aws_secretsmanager_secret.api_social_login.arn}:ZOOP_AUTH_SOCIAL_GOOGLE_CLIENT_ID::"
        },
        {
          name      = "ZOOP_AUTH_SOCIAL_GOOGLE_CLIENT_SECRET"
          valueFrom = "${aws_secretsmanager_secret.api_social_login.arn}:ZOOP_AUTH_SOCIAL_GOOGLE_CLIENT_SECRET::"
        },
        {
          name      = "ZOOP_AUTH_SOCIAL_KAKAO_CLIENT_ID"
          valueFrom = "${aws_secretsmanager_secret.api_social_login.arn}:ZOOP_AUTH_SOCIAL_KAKAO_CLIENT_ID::"
        },
        {
          name      = "ZOOP_AUTH_SOCIAL_KAKAO_CLIENT_SECRET"
          valueFrom = "${aws_secretsmanager_secret.api_social_login.arn}:ZOOP_AUTH_SOCIAL_KAKAO_CLIENT_SECRET::"
        },
        {
          name      = "ZOOP_TOSS_CLIENT_ID"
          valueFrom = "${aws_secretsmanager_secret.api_toss.arn}:ZOOP_TOSS_CLIENT_ID::"
        },
        {
          name      = "ZOOP_TOSS_CLIENT_SECRET"
          valueFrom = "${aws_secretsmanager_secret.api_toss.arn}:ZOOP_TOSS_CLIENT_SECRET::"
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

      linuxParameters = {
        initProcessEnabled = true
      }

      portMappings = [
        {
          name          = "ai-http"
          containerPort = var.ai_container_port
          hostPort      = var.ai_container_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      environment = [
        {
          name  = "ZOOP_AI_SERVICE_PORT"
          value = tostring(var.ai_container_port)
        },
        {
          name  = "ZOOP_AI_SERVICE_STATE_DIR"
          value = "/var/lib/zoop-ai/service"
        },
        {
          name  = "ZOOP_AI_WORKER_STATE_DIR"
          value = "/var/lib/zoop-ai/worker"
        }
      ]

      secrets = [
        {
          name      = "ZOOP_AI_SERVICE_PRINCIPALS"
          valueFrom = "${aws_secretsmanager_secret.ai_auth.arn}:service_principals::"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "ai-service-state"
          containerPath = "/var/lib/zoop-ai/service"
          readOnly      = false
        },
        {
          sourceVolume  = "ai-worker-state"
          containerPath = "/var/lib/zoop-ai/worker"
          readOnly      = false
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "/opt/zoop/service/.venv/bin/python -c \"import socket; connection=socket.create_connection(('127.0.0.1', ${var.ai_container_port}), 3); connection.close()\""
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }

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

  volume {
    name = "ai-service-state"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.ai_state.id
      root_directory     = "/"
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.ai_service_state.id
        iam             = "ENABLED"
      }
    }
  }

  volume {
    name = "ai-worker-state"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.ai_state.id
      root_directory     = "/"
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.ai_worker_state.id
        iam             = "ENABLED"
      }
    }
  }

  depends_on = [
    aws_iam_role_policy.ai_runtime_secret_access,
    aws_iam_role_policy.ai_efs_access,
    aws_iam_role_policy.ai_ecs_exec,
    aws_secretsmanager_secret_version.ai_auth
  ]

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

  lifecycle {
    ignore_changes = [
      task_definition
    ]
  }

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

  depends_on = [
    aws_efs_mount_target.ai_state_a,
    aws_efs_mount_target.ai_state_c,
    aws_vpc_security_group_ingress_rule.ai_efs_from_ai
  ]

  tags = {
    Name    = "${local.ecs_name}-ai"
    Service = "ai"
  }
}