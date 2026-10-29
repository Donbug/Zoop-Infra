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
