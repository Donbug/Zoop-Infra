locals {
  ai_collection_container_name = "ai-collection"
  ai_collection_image_tag      = "0a9efa9d6c6a3df3eb079a023ef4a585c8caa574-amd64"
}

resource "aws_ecs_task_definition" "ai_collection" {
  family                   = "${local.ecs_name}-ai-collection"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ai_collection_task_execution.arn
  task_role_arn            = aws_iam_role.ai_collection_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  ephemeral_storage {
    size_in_gib = 50
  }

  container_definitions = jsonencode([
    {
      name      = local.ai_collection_container_name
      image     = "${aws_ecr_repository.service["ai-collection"].repository_url}:${local.ai_collection_image_tag}"
      essential = true

      stopTimeout = 120

      readonlyRootFilesystem = false

      environment = [
        {
          name  = "ZOOP_COLLECTOR_BUCKET"
          value = aws_s3_bucket.ai_collection.id
        },
        {
          name  = "ZOOP_COLLECTOR_STATE_DIR"
          value = "/var/lib/zoop-collector"
        },
        {
          name  = "ZOOP_COLLECTOR_RESTORE"
          value = "auto"
        }
      ]

      linuxParameters = {
        initProcessEnabled = true
      }

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs["ai-collection"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ai-collection"
        }
      }
    }
  ])

  depends_on = [
    aws_cloudwatch_log_group.ecs,
    aws_iam_role_policy_attachment.ai_collection_task_execution,
    aws_iam_role_policy.ai_collection_s3_access,
    aws_iam_role_policy.ai_collection_ecs_exec
  ]

  tags = {
    Name    = "${local.ecs_name}-ai-collection"
    Service = "ai-collection"
  }
}
