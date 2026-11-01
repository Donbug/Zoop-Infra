locals {
  first47_access_points = {
    artifacts = {
      path = "/first47/artifacts"
      uid  = 100
      gid  = 101
    }

    operations = {
      path = "/first47/operations"
      uid  = 100
      gid  = 101
    }

    delivery = {
      path = "/first47/delivery"
      uid  = 100
      gid  = 101
    }

    authority = {
      path = "/first47/authority"
      uid  = 999
      gid  = 999
    }

    ai_archive = {
      path = "/first47/ai-archive"
      uid  = 999
      gid  = 999
    }
  }
}

resource "aws_security_group" "first47_staging" {
  name        = "${local.ecs_name}-first47-staging-sg"
  description = "Security group for the first47 S3 to EFS staging RunTask"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "${local.ecs_name}-first47-staging-sg"
    Service = "first47-staging"
  }
}

resource "aws_vpc_security_group_egress_rule" "first47_staging_all_egress" {
  security_group_id = aws_security_group.first47_staging.id
  description       = "Allow first47 staging access to AWS services"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "ai_efs_from_api" {
  security_group_id            = aws_security_group.ai_efs.id
  description                  = "Allow NFS mounts from API web and first47 operator tasks"
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ai_efs_from_first47_staging" {
  security_group_id            = aws_security_group.ai_efs.id
  description                  = "Allow NFS mounts from the first47 staging RunTask"
  referenced_security_group_id = aws_security_group.first47_staging.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}

resource "aws_efs_access_point" "first47" {
  for_each = local.first47_access_points

  file_system_id = aws_efs_file_system.ai_state.id

  posix_user {
    uid = each.value.uid
    gid = each.value.gid
  }

  root_directory {
    path = each.value.path

    creation_info {
      owner_uid   = each.value.uid
      owner_gid   = each.value.gid
      permissions = "0700"
    }
  }

  tags = {
    Name    = "${local.ecs_name}-first47-${replace(each.key, "_", "-")}"
    Service = "first47"
    Purpose = each.key
  }
}
