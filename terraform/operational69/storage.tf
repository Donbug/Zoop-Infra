locals {
  ap_identity = {
    archive   = { uid = 999, gid = 999 }
    authority = { uid = 999, gid = 999 }
    control   = { uid = 100, gid = 101 }
  }
}

resource "aws_efs_access_point" "new" {
  for_each       = local.ap_identity
  file_system_id = data.aws_efs_file_system.existing.id
  posix_user {
    uid = each.value.uid
    gid = each.value.gid
  }
  root_directory {
    path = "/operational69/${each.key}"
    creation_info {
      owner_uid   = each.value.uid
      owner_gid   = each.value.gid
      permissions = "0700"
    }
  }
  lifecycle {
    precondition {
      condition = (
        data.aws_caller_identity.current.account_id == var.expected_account_id &&
        split(":", var.existing.cluster_arn)[4] == var.expected_account_id &&
        alltrue([for image in [var.images.reader, var.images.operator] : split(":", image.repository_arn)[4] == var.expected_account_id]) &&
        alltrue([for arn in concat([var.database.credentials_arn, var.database.csrf_secret_arn], tolist(var.database.kms_key_arns)) : split(":", arn)[4] == var.expected_account_id])
      )
      error_message = "All supplied metadata identities must belong to the approved account."
    }
  }
  tags = { Name = "${local.name}-${each.key}" }
}

resource "aws_secretsmanager_secret" "new" {
  for_each                = toset(["api-reader-token", "reader-principals"])
  name                    = "zoop-dev/operational69/${each.key}"
  recovery_window_in_days = 7
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "task" {
  for_each          = toset(["reader", "stage", "operator"])
  name              = "/ecs/zoop-dev/operational69-${each.key}"
  retention_in_days = 14
}

locals {
  reader_mounts = {
    archive       = { ap = aws_efs_access_point.new["archive"].id, path = "/srv/zoop-op69/archive", ro = true }
    authority     = { ap = aws_efs_access_point.new["authority"].id, path = "/mnt/zoop-op69-authority", ro = true }
    control       = { ap = aws_efs_access_point.new["control"].id, path = "/mnt/zoop-op69-control", ro = true }
    old_archive   = { ap = var.existing.access_points.archive, path = "/srv/zoop-ai-read/archive", ro = true }
    old_authority = { ap = var.existing.access_points.authority, path = "/mnt/zoop-authority", ro = true }
  }
  stage_mounts = {
    operations = { ap = var.existing.access_points.operations, path = "/mnt/zoop-ops", ro = true }
    archive    = { ap = aws_efs_access_point.new["archive"].id, path = "/srv/zoop-op69/archive", ro = false }
  }
  operator_mounts = {
    authority     = { ap = aws_efs_access_point.new["authority"].id, path = "/mnt/zoop-op69-authority", ro = true }
    old_authority = { ap = var.existing.access_points.authority, path = "/mnt/zoop-authority", ro = true }
    control       = { ap = aws_efs_access_point.new["control"].id, path = "/mnt/zoop-op69-control", ro = false }
    artifacts     = { ap = var.existing.access_points.artifacts, path = "/mnt/zoop-artifacts", ro = false }
  }
}
