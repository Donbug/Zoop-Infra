locals {
  stage_container = {
    name                   = "stage"
    image                  = var.images.reader.pin
    user                   = "0:0"
    essential              = true
    readonlyRootFilesystem = true
    entryPoint             = [var.reader_python, "-B", "-c", file("${path.module}/scripts/stage_operational69.py")]
    command = [
      "--archive", var.archive.source_path,
      "--manifest", var.archive.manifest_path,
      "--archive-sha256", var.archive.sha256,
      "--manifest-sha256", var.archive.manifest_sha256,
      "--destination", "/srv/zoop-op69/archive"
    ]
    environment = [{ name = "PYTHONDONTWRITEBYTECODE", value = "1" }]
    mountPoints = concat([for key, m in local.stage_mounts : { sourceVolume = key, containerPath = m.path, readOnly = m.ro }], [
      { sourceVolume = "tmp", containerPath = "/tmp", readOnly = false }
    ])
    linuxParameters = { initProcessEnabled = true }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.task["stage"].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "stage"
      }
    }
  }
}

resource "aws_ecs_task_definition" "stage" {
  family                   = "${local.name}-stage"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.execution["stage"].arn
  task_role_arn            = aws_iam_role.task["stage"].arn
  container_definitions    = jsonencode([local.stage_container])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  dynamic "volume" {
    for_each = local.stage_mounts
    content {
      name = volume.key
      efs_volume_configuration {
        file_system_id     = var.existing.efs_id
        root_directory     = "/"
        transit_encryption = "ENABLED"
        authorization_config {
          access_point_id = volume.value.ap
          iam             = "ENABLED"
        }
      }
    }
  }
  volume {
    name = "tmp"
  }
  depends_on = [aws_iam_role_policy.execution, aws_iam_role_policy.efs]
}
