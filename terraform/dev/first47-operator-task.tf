locals {
  first47_operator_container_name = "first47-operator"

  first47_operator_mounts = {
    artifacts = {
      volume_name      = "first47-artifacts"
      access_point_key = "artifacts"
      container_path   = "/mnt/zoop-artifacts"
      read_only        = false
    }

    operations = {
      volume_name      = "first47-operations"
      access_point_key = "operations"
      container_path   = "/mnt/zoop-ops"
      read_only        = false
    }

    delivery = {
      volume_name      = "first47-delivery"
      access_point_key = "delivery"
      container_path   = "/mnt/zoop-first47"
      read_only        = true
    }

    authority = {
      volume_name      = "first47-authority"
      access_point_key = "authority"
      container_path   = "/mnt/zoop-authority"
      read_only        = true
    }
  }
}

data "aws_secretsmanager_secret" "first47_api_ai_token" {
  name = "zoop-dev/first47/api-ai-token"
}

resource "aws_ecs_task_definition" "first47_operator" {
  family                   = "${local.ecs_name}-first47-operator"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.api_task_cpu)
  memory                   = tostring(var.api_task_memory)
  execution_role_arn       = aws_iam_role.first47_operator_execution.arn
  task_role_arn            = aws_iam_role.first47_operator_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = local.first47_operator_container_name
      image     = "${aws_ecr_repository.service["api"].repository_url}:${var.api_image_tag}"
      essential = true
      command   = ["--spring.main.web-application-type=none"]

      readonlyRootFilesystem = true

      environment = [
        {
          name  = "DB_URL"
          value = "jdbc:postgresql://${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.rds_database_name}"
        },
        {
          name  = "ZOOP_AUTH_CSRF_ACTIVE_KEY_ID"
          value = "dev-v1"
        },
        {
          name  = "ZOOP_GRAPH_SNAPSHOT_SOURCE"
          value = "none"
        },
        {
          name  = "ZOOP_DOCUMENT_READ_INGESTION_SOURCES"
          value = "/mnt/zoop-authority/serving-authorities.json"
        },
        {
          name  = "ZOOP_DOCUMENT_READ_ARTIFACT_ROOT"
          value = "/mnt/zoop-artifacts"
        },
        {
          name  = "ZOOP_DOCUMENT_IMPORT_ENABLED"
          value = "false"
        },
        {
          name  = "ZOOP_DOCUMENT_BINDINGS_ENABLED"
          value = "false"
        },
        {
          name  = "ZOOP_GRAPH_HANDOFF_IMPORT_ENABLED"
          value = "false"
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
        },
        {
          name  = "ZOOP_AI_HANDOFF_READ_CLIENT_ENABLED"
          value = "false"
        },
        {
          name  = "ZOOP_AI_OBSERVATION_EXPORT_CLIENT_ENABLED"
          value = "false"
        },
        {
          name  = "SPRING_FLYWAY_ENABLED"
          value = "false"
        },
        {
          name  = "SPRING_JPA_HIBERNATE_DDL_AUTO"
          value = "validate"
        },
        {
          name  = "SPRING_SQL_INIT_MODE"
          value = "never"
        },
        {
          name  = "ZOOP_GRAPH_AUTO_ACTIVATION_ENABLED"
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
          name      = "ZOOP_AI_HANDOFF_READ_CLIENT_TOKEN"
          valueFrom = data.aws_secretsmanager_secret.first47_api_ai_token.arn
        },
        {
          name      = "ZOOP_AI_OBSERVATION_EXPORT_CLIENT_TOKEN"
          valueFrom = data.aws_secretsmanager_secret.first47_api_ai_token.arn
        }
      ]

      mountPoints = concat(
        [
          for mount in values(local.first47_operator_mounts) : {
            sourceVolume  = mount.volume_name
            containerPath = mount.container_path
            readOnly      = mount.read_only
          }
        ],
        [
          {
            sourceVolume  = "first47-operator-tmp"
            containerPath = "/tmp"
            readOnly      = false
          }
        ]
      )

      linuxParameters = {
        initProcessEnabled = true
      }

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs["api"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "first47-operator"
        }
      }
    }
  ])

  dynamic "volume" {
    for_each = local.first47_operator_mounts

    content {
      name = volume.value.volume_name

      efs_volume_configuration {
        file_system_id     = aws_efs_file_system.ai_state.id
        root_directory     = "/"
        transit_encryption = "ENABLED"

        authorization_config {
          access_point_id = aws_efs_access_point.first47[volume.value.access_point_key].id
          iam             = "ENABLED"
        }
      }
    }
  }

  volume {
    name = "first47-operator-tmp"
  }

  depends_on = [
    aws_iam_role_policy_attachment.first47_operator_execution,
    aws_iam_role_policy.first47_operator_runtime_secret_access,
    aws_iam_role_policy.first47_operator_efs_access,
    aws_iam_role_policy.first47_operator_ecs_exec
  ]

  tags = {
    Name    = "${local.ecs_name}-first47-operator"
    Service = "first47-operator"
    Purpose = "first47-b1-b4-run-task"
  }
}

output "first47_operator_task_definition_arn" {
  description = "ARN of the first47 B1-B4 one-off operator task definition"
  value       = aws_ecs_task_definition.first47_operator.arn
}

output "first47_operator_task_role_arn" {
  description = "Task role used by the first47 operator task"
  value       = aws_iam_role.first47_operator_task.arn
}
