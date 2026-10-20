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

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.ecs_name}-task-execution-role"
  description        = "Allows ECS to pull images and publish container logs"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name = "${local.ecs_name}-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
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
      aws_secretsmanager_secret.api_csrf.arn
    ]
  }
}

resource "aws_iam_role_policy" "api_runtime_secret_access" {
  name   = "${local.ecs_name}-api-runtime-secret-access"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.api_runtime_secret_access.json
}