data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.expected_account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:ecs:${var.aws_region}:${var.expected_account_id}:*"]
    }
  }
}

resource "aws_iam_role" "execution" {
  for_each           = toset(["reader", "stage", "operator"])
  name               = "${local.name}-${each.key}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role" "task" {
  for_each           = toset(["reader", "stage", "operator"])
  name               = "${local.name}-${each.key}-task-role"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

locals {
  execution_secrets = {
    reader   = [aws_secretsmanager_secret.new["reader-principals"].arn]
    stage    = []
    operator = [aws_secretsmanager_secret.new["api-reader-token"].arn, var.database.credentials_arn, var.database.csrf_secret_arn]
  }
  mounts = { reader = local.reader_mounts, stage = local.stage_mounts, operator = local.operator_mounts }
  ap_arns = {
    for kind, mounts in local.mounts : kind => {
      ro = [for m in values(mounts) : "arn:aws:elasticfilesystem:${var.aws_region}:${var.expected_account_id}:access-point/${m.ap}" if m.ro]
      rw = [for m in values(mounts) : "arn:aws:elasticfilesystem:${var.aws_region}:${var.expected_account_id}:access-point/${m.ap}" if !m.ro]
    }
  }
}

data "aws_iam_policy_document" "execution" {
  for_each = aws_iam_role.execution
  statement {
    sid       = "EcrAuthorization"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid       = "PinnedRepositoryPull"
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
    resources = [each.key == "operator" ? var.images.operator.repository_arn : var.images.reader.repository_arn]
  }
  statement {
    sid       = "TaskLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.task[each.key].arn}:*"]
  }
  dynamic "statement" {
    for_each = length(local.execution_secrets[each.key]) == 0 ? [] : [local.execution_secrets[each.key]]
    content {
      sid       = "RuntimeSecretInjection"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = statement.value
    }
  }
  dynamic "statement" {
    for_each = each.key == "operator" && length(var.database.kms_key_arns) > 0 ? [var.database.kms_key_arns] : []
    content {
      sid       = "ReferencedSecretKeys"
      actions   = ["kms:Decrypt"]
      resources = statement.value
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_role_policy" "execution" {
  for_each = aws_iam_role.execution
  name     = "runtime-delivery"
  role     = each.value.id
  policy   = data.aws_iam_policy_document.execution[each.key].json
}

data "aws_iam_policy_document" "efs" {
  for_each = local.ap_arns
  dynamic "statement" {
    for_each = { for mode, arns in each.value : mode => arns if length(arns) > 0 }
    content {
      sid       = statement.key == "ro" ? "ReadOnlyAccessPoints" : "WritableAccessPoints"
      actions   = statement.key == "ro" ? ["elasticfilesystem:ClientMount"] : ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
      resources = [local.fs_arn]
      condition {
        test     = "StringEquals"
        variable = "elasticfilesystem:AccessPointArn"
        values   = statement.value
      }
      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["true"]
      }
    }
  }
}

resource "aws_iam_role_policy" "efs" {
  for_each = aws_iam_role.task
  name     = "access-point-files"
  role     = each.value.id
  policy   = data.aws_iam_policy_document.efs[each.key].json
}
