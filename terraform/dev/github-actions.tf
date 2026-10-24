locals {
  # GitHub immutable OIDC identity:
  # Donbug organization ID: 331190325
  # zoop repository ID: 1399101385
  github_actions_repository  = "Donbug@331190325/zoop@1399101385"
  github_actions_environment = "dev"

  github_actions_subject = "repo:${local.github_actions_repository}:environment:${local.github_actions_environment}"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Name    = "${local.ecs_name}-github-actions-oidc"
    Service = "github-actions"
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    sid     = "AllowGitHubActionsFromDevEnvironment"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github_actions.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        local.github_actions_subject
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name                 = "${local.ecs_name}-github-actions-deploy-role"
  description          = "Allows the Donbug/zoop dev environment to push images and deploy ECS services"
  assume_role_policy   = data.aws_iam_policy_document.github_actions_assume_role.json
  max_session_duration = 3600

  tags = {
    Name    = "${local.ecs_name}-github-actions-deploy-role"
    Service = "github-actions"
  }
}

data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid       = "GetECRAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushImagesToServiceRepositories"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [
      for repository in aws_ecr_repository.service :
      repository.arn
    ]
  }

  statement {
    sid    = "ReadECSDeploymentState"
    effect = "Allow"

    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:ListTaskDefinitions"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "RegisterZOOPTaskDefinitions"
    effect = "Allow"

    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:TagResource"
    ]

    resources = [
      "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${local.ecs_name}-*"
    ]
  }

  statement {
    sid     = "UpdateZOOPServices"
    effect  = "Allow"
    actions = ["ecs:UpdateService"]

    resources = [
      aws_ecs_service.api.arn,
      aws_ecs_service.ai.arn
    ]
  }

  statement {
    sid     = "PassOnlyZOOPTaskRoles"
    effect  = "Allow"
    actions = ["iam:PassRole"]

    resources = [
      aws_iam_role.api_task_execution.arn,
      aws_iam_role.ai_task_execution.arn,
      aws_iam_role.api_task.arn,
      aws_iam_role.ai_task.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_image_stage" {
  name                 = "${local.ecs_name}-github-actions-image-stage-role"
  description          = "Allows the Donbug/zoop dev environment to stage API images in ECR"
  assume_role_policy   = data.aws_iam_policy_document.github_actions_assume_role.json
  max_session_duration = 3600

  tags = {
    Name    = "${local.ecs_name}-github-actions-image-stage-role"
    Service = "github-actions"
    Scope   = "image-stage"
  }
}

data "aws_iam_policy_document" "github_actions_image_stage" {
  statement {
    sid       = "GetECRAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "StageApiImages"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [
      aws_ecr_repository.service["api"].arn
    ]
  }
}

resource "aws_iam_role_policy" "github_actions_image_stage" {
  name   = "${local.ecs_name}-github-actions-image-stage-policy"
  role   = aws_iam_role.github_actions_image_stage.id
  policy = data.aws_iam_policy_document.github_actions_image_stage.json
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "${local.ecs_name}-github-actions-deploy-policy"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}

output "github_actions_deploy_role_arn" {
  description = "IAM role ARN assumed by the Donbug/zoop GitHub Actions dev environment"
  value       = aws_iam_role.github_actions_deploy.arn
}

output "github_actions_image_stage_role_arn" {
  description = "IAM role ARN used by Donbug/zoop GitHub Actions to stage API images in ECR"
  value       = aws_iam_role.github_actions_image_stage.arn
}
