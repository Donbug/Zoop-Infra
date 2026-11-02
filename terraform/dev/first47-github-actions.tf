locals {
  # GitHub immutable OIDC identity:
  # Donbug organization ID: 331190325
  # Zoop-Infra repository ID: 1406879645
  first47_github_actions_repository = "Donbug@331190325/Zoop-Infra@1406879645"
  first47_github_actions_subject    = "repo:${local.first47_github_actions_repository}:ref:refs/heads/main"
}

data "aws_iam_policy_document" "first47_github_actions_assume_role" {
  statement {
    sid     = "AllowZoopInfraMainBranch"
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
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.first47_github_actions_subject]
    }
  }
}

resource "aws_iam_role" "first47_github_actions_image_stage" {
  name                 = "${local.ecs_name}-first47-image-stage-role"
  description          = "Allows Zoop-Infra main to publish only the first47 staging image"
  assume_role_policy   = data.aws_iam_policy_document.first47_github_actions_assume_role.json
  max_session_duration = 3600

  tags = {
    Name    = "${local.ecs_name}-first47-image-stage-role"
    Service = "first47"
    Scope   = "image-stage"
  }
}

data "aws_iam_policy_document" "first47_github_actions_image_stage" {
  statement {
    sid       = "GetECRAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushOnlyFirst47StagingImage"
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
      aws_ecr_repository.service["first47-staging"].arn
    ]
  }
}

resource "aws_iam_role_policy" "first47_github_actions_image_stage" {
  name   = "${local.ecs_name}-first47-image-stage-policy"
  role   = aws_iam_role.first47_github_actions_image_stage.id
  policy = data.aws_iam_policy_document.first47_github_actions_image_stage.json
}

output "first47_github_actions_image_stage_role_arn" {
  description = "IAM role ARN used by Zoop-Infra main to publish the first47 staging image"
  value       = aws_iam_role.first47_github_actions_image_stage.arn
}
