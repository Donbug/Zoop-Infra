locals {
  first47_staging_container_name = "first47-staging"

  first47_staging_image = "512138915880.dkr.ecr.ap-northeast-2.amazonaws.com/zoop-dev-first47-staging@sha256:18a3a49e0fe8ec176c1ce8be887019e96cfef98fd3d78b5558ba3fbb792cccd7"

  first47_staging_object_keys = [
    "handoffs/first47-infra/d936941a9b57760f5a88e4c5864f8ad2da82e7e01a27ab3c15aa54e2629a2baa/MANIFEST.json",
    "handoffs/first47-infra/d936941a9b57760f5a88e4c5864f8ad2da82e7e01a27ab3c15aa54e2629a2baa/SHA256SUMS",
    "handoffs/first47-infra/d936941a9b57760f5a88e4c5864f8ad2da82e7e01a27ab3c15aa54e2629a2baa/DELIVERY.tar.gz",
    "handoffs/private-native-read/71a36db7bfa363989c781d2d6ea1a278b7dd09df648836710f75e230b07eb99f/MANIFEST.json",
    "handoffs/private-native-read/71a36db7bfa363989c781d2d6ea1a278b7dd09df648836710f75e230b07eb99f/private-native-read-with-authorities-r2.tar.gz"
  ]

  first47_staging_mounts = {
    delivery = {
      volume_name      = "first47-delivery"
      access_point_key = "delivery"
      container_path   = "/mnt/zoop-first47"
    }

    authority = {
      volume_name      = "first47-authority"
      access_point_key = "authority"
      container_path   = "/mnt/zoop-authority"
    }

    ai_archive = {
      volume_name      = "first47-ai-archive"
      access_point_key = "ai_archive"
      container_path   = "/srv/zoop-ai-read/archive"
    }

    operations = {
      volume_name      = "first47-operations"
      access_point_key = "operations"
      container_path   = "/mnt/zoop-ops"
    }
  }
}

resource "aws_iam_role" "first47_staging_execution" {
  name               = "${local.ecs_name}-first47-staging-execution-role"
  description        = "Allows ECS to pull the pinned first47 staging image and publish logs"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name    = "${local.ecs_name}-first47-staging-execution-role"
    Service = "first47"
  }
}

data "aws_iam_policy_document" "first47_staging_execution" {
  statement {
    sid       = "GetECRAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PullFirst47StagingImage"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]

    resources = [
      aws_ecr_repository.service["first47-staging"].arn
    ]
  }

  statement {
    sid    = "WriteFirst47StagingLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "${aws_cloudwatch_log_group.ecs["first47-staging"].arn}:*"
    ]
  }
}

resource "aws_iam_role_policy" "first47_staging_execution" {
  name   = "${local.ecs_name}-first47-staging-execution-policy"
  role   = aws_iam_role.first47_staging_execution.id
  policy = data.aws_iam_policy_document.first47_staging_execution.json
}

resource "aws_iam_role" "first47_staging_task" {
  name               = "${local.ecs_name}-first47-staging-task-role"
  description        = "IAM role assumed by the first47 S3 to EFS staging task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name    = "${local.ecs_name}-first47-staging-task-role"
    Service = "first47"
  }
}

data "aws_iam_policy_document" "first47_staging_s3_read" {
  statement {
    sid    = "ReadPinnedFirst47ObjectVersions"
    effect = "Allow"

    actions = [
      "s3:GetObjectVersion"
    ]

    resources = [
      for key in local.first47_staging_object_keys :
      "${aws_s3_bucket.ai_collection.arn}/${key}"
    ]
  }
}

resource "aws_iam_role_policy" "first47_staging_s3_read" {
  name   = "${local.ecs_name}-first47-staging-s3-read"
  role   = aws_iam_role.first47_staging_task.id
  policy = data.aws_iam_policy_document.first47_staging_s3_read.json
}

data "aws_iam_policy_document" "first47_staging_efs_access" {
  statement {
    sid    = "MountAndWriteFirst47AccessPoints"
    effect = "Allow"

    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite"
    ]

    resources = [
      aws_efs_file_system.ai_state.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "elasticfilesystem:AccessPointArn"

      values = [
        for key in ["delivery", "authority", "ai_archive", "operations"] :
        aws_efs_access_point.first47[key].arn
      ]
    }
  }
}

resource "aws_iam_role_policy" "first47_staging_efs_access" {
  name   = "${local.ecs_name}-first47-staging-efs-access"
  role   = aws_iam_role.first47_staging_task.id
  policy = data.aws_iam_policy_document.first47_staging_efs_access.json
}

resource "aws_ecs_task_definition" "first47_staging" {
  family                   = "${local.ecs_name}-first47-staging"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.first47_staging_execution.arn
  task_role_arn            = aws_iam_role.first47_staging_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = local.first47_staging_container_name
      image     = local.first47_staging_image
      essential = true

      readonlyRootFilesystem = true

      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "FIRST47_BUCKET"
          value = aws_s3_bucket.ai_collection.id
        },
        {
          name  = "FIRST47_DELIVERY_ROOT"
          value = "/mnt/zoop-first47"
        },
        {
          name  = "FIRST47_AUTHORITY_ROOT"
          value = "/mnt/zoop-authority"
        },
        {
          name  = "FIRST47_AI_ARCHIVE_ROOT"
          value = "/srv/zoop-ai-read/archive"
        },
        {
          name  = "FIRST47_OPS_ROOT"
          value = "/mnt/zoop-ops"
        }
      ]

      mountPoints = concat(
        [
          for mount in values(local.first47_staging_mounts) : {
            sourceVolume  = mount.volume_name
            containerPath = mount.container_path
            readOnly      = false
          }
        ],
        [
          {
            sourceVolume  = "first47-tmp"
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
          "awslogs-group"         = aws_cloudwatch_log_group.ecs["first47-staging"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "first47-staging"
        }
      }
    }
  ])

  dynamic "volume" {
    for_each = local.first47_staging_mounts

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
    name = "first47-tmp"
  }

  depends_on = [
    aws_iam_role_policy.first47_staging_execution,
    aws_iam_role_policy.first47_staging_s3_read,
    aws_iam_role_policy.first47_staging_efs_access
  ]

  tags = {
    Name    = "${local.ecs_name}-first47-staging"
    Service = "first47"
    Purpose = "s3-to-efs-staging"
  }
}

output "first47_staging_task_definition_arn" {
  description = "ARN of the first47 one-off staging task definition"
  value       = aws_ecs_task_definition.first47_staging.arn
}

output "first47_staging_task_role_arn" {
  description = "Task role used by the first47 staging container"
  value       = aws_iam_role.first47_staging_task.arn
}

output "first47_staging_execution_role_arn" {
  description = "Execution role used by ECS for the first47 staging task"
  value       = aws_iam_role.first47_staging_execution.arn
}
