data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"

      identifiers = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "api_task_execution" {
  name               = "${local.ecs_name}-api-task-execution-role"
  description        = "Allows the ZOOP API task to pull images, publish logs, and read API runtime secrets"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name    = "${local.ecs_name}-api-task-execution-role"
    Service = "api"
  }
}

resource "aws_iam_role_policy_attachment" "api_task_execution" {
  role       = aws_iam_role.api_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ai_task_execution" {
  name               = "${local.ecs_name}-ai-task-execution-role"
  description        = "Allows the ZOOP AI task to pull images and publish container logs"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name    = "${local.ecs_name}-ai-task-execution-role"
    Service = "ai"
  }
}

resource "aws_iam_role_policy_attachment" "ai_task_execution" {
  role       = aws_iam_role.ai_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "api_task" {
  name               = "${local.ecs_name}-api-task-role"
  description        = "IAM role assumed by the ZOOP API container"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name    = "${local.ecs_name}-api-task-role"
    Service = "api"
  }
}

resource "aws_iam_role" "ai_task" {
  name               = "${local.ecs_name}-ai-task-role"
  description        = "IAM role assumed by the ZOOP AI container"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name    = "${local.ecs_name}-ai-task-role"
    Service = "ai"
  }
}

data "aws_iam_policy_document" "api_runtime_secret_access" {
  statement {
    sid    = "ReadApiRuntimeSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      aws_db_instance.postgres.master_user_secret[0].secret_arn,
      aws_secretsmanager_secret.api_csrf.arn,
      aws_secretsmanager_secret.api_social_login.arn,
      aws_secretsmanager_secret.api_toss.arn
    ]
  }
}

resource "aws_iam_role_policy" "api_runtime_secret_access" {
  name   = "${local.ecs_name}-api-runtime-secret-access"
  role   = aws_iam_role.api_task_execution.id
  policy = data.aws_iam_policy_document.api_runtime_secret_access.json
}

data "aws_iam_policy_document" "ai_runtime_secret_access" {
  statement {
    sid    = "ReadAiRuntimeSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      aws_secretsmanager_secret.ai_auth.arn
    ]
  }
}

resource "aws_iam_role_policy" "ai_runtime_secret_access" {
  name   = "${local.ecs_name}-ai-runtime-secret-access"
  role   = aws_iam_role.ai_task_execution.id
  policy = data.aws_iam_policy_document.ai_runtime_secret_access.json
}

data "aws_iam_policy_document" "ai_efs_access" {
  statement {
    sid    = "MountAiStateFileSystem"
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
        aws_efs_access_point.ai_service_state.arn,
        aws_efs_access_point.ai_worker_state.arn
      ]
    }
  }
}

resource "aws_iam_role_policy" "ai_efs_access" {
  name   = "${local.ecs_name}-ai-efs-access"
  role   = aws_iam_role.ai_task.id
  policy = data.aws_iam_policy_document.ai_efs_access.json
}

data "aws_iam_policy_document" "api_ecs_exec" {
  statement {
    sid    = "UseEcsExecChannels"
    effect = "Allow"

    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "api_ecs_exec" {
  name   = "${local.ecs_name}-api-ecs-exec"
  role   = aws_iam_role.api_task.id
  policy = data.aws_iam_policy_document.api_ecs_exec.json
}

data "aws_iam_policy_document" "ai_ecs_exec" {
  statement {
    sid    = "UseEcsExecChannels"
    effect = "Allow"

    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ai_ecs_exec" {
  name   = "${local.ecs_name}-ai-ecs-exec"
  role   = aws_iam_role.ai_task.id
  policy = data.aws_iam_policy_document.ai_ecs_exec.json
}

# -------------------------------------------------------------------
# AI Collection Task IAM roles
# -------------------------------------------------------------------

resource "aws_iam_role" "ai_collection_task_execution" {
  name               = "${local.ecs_name}-ai-collection-task-execution-role"
  description        = "Allows ECS to pull the AI collection image and publish container logs"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name    = "${local.ecs_name}-ai-collection-task-execution-role"
    Service = "ai-collection"
  }
}

resource "aws_iam_role_policy_attachment" "ai_collection_task_execution" {
  role       = aws_iam_role.ai_collection_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ai_collection_task" {
  name               = "${local.ecs_name}-ai-collection-task-role"
  description        = "IAM role assumed by the ZOOP AI collection container"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name    = "${local.ecs_name}-ai-collection-task-role"
    Service = "ai-collection"
  }
}

data "aws_iam_policy_document" "ai_collection_s3_access" {
  statement {
    sid    = "AccessAiCollectionBucket"
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListBucketVersions"
    ]

    resources = [
      aws_s3_bucket.ai_collection.arn
    ]
  }

  statement {
    sid    = "ReadWriteAiCollectionObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]

    resources = [
      "${aws_s3_bucket.ai_collection.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "ai_collection_s3_access" {
  name   = "${local.ecs_name}-ai-collection-s3-access"
  role   = aws_iam_role.ai_collection_task.id
  policy = data.aws_iam_policy_document.ai_collection_s3_access.json
}

data "aws_iam_policy_document" "ai_collection_ecs_exec" {
  statement {
    sid    = "UseEcsExecChannels"
    effect = "Allow"

    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ai_collection_ecs_exec" {
  name   = "${local.ecs_name}-ai-collection-ecs-exec"
  role   = aws_iam_role.ai_collection_task.id
  policy = data.aws_iam_policy_document.ai_collection_ecs_exec.json
}

data "aws_iam_policy_document" "ai_collection_runtime_secret_access" {
  statement {
    sid    = "ReadAiCollectionRuntimeSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      aws_secretsmanager_secret.ai_collection.arn
    ]
  }
}

resource "aws_iam_role_policy" "ai_collection_runtime_secret_access" {
  name   = "${local.ecs_name}-ai-collection-runtime-secret-access"
  role   = aws_iam_role.ai_collection_task_execution.id
  policy = data.aws_iam_policy_document.ai_collection_runtime_secret_access.json
}
