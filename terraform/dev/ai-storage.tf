resource "aws_security_group" "ai_efs" {
  name        = "${local.ecs_name}-ai-efs-sg"
  description = "Allows the AI Fargate service to mount its EFS state"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "${local.ecs_name}-ai-efs-sg"
    Service = "ai"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ai_efs_from_ai" {
  security_group_id            = aws_security_group.ai_efs.id
  description                  = "Allow NFS mounts from the AI Fargate service"
  referenced_security_group_id = aws_security_group.ai.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}

resource "aws_efs_file_system" "ai_state" {
  creation_token   = "${local.ecs_name}-ai-state"
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = "${local.ecs_name}-ai-state"
    Service = "ai"
  }
}

resource "aws_efs_mount_target" "ai_state_a" {
  file_system_id  = aws_efs_file_system.ai_state.id
  subnet_id       = aws_subnet.private_app_a.id
  security_groups = [aws_security_group.ai_efs.id]
}

resource "aws_efs_mount_target" "ai_state_c" {
  file_system_id  = aws_efs_file_system.ai_state.id
  subnet_id       = aws_subnet.private_app_c.id
  security_groups = [aws_security_group.ai_efs.id]
}

resource "aws_efs_access_point" "ai_service_state" {
  file_system_id = aws_efs_file_system.ai_state.id

  posix_user {
    uid = 999
    gid = 999
  }

  root_directory {
    path = "/service"

    creation_info {
      owner_uid   = 999
      owner_gid   = 999
      permissions = "0700"
    }
  }

  tags = {
    Name    = "${local.ecs_name}-ai-service-state"
    Service = "ai"
  }
}

resource "aws_efs_access_point" "ai_worker_state" {
  file_system_id = aws_efs_file_system.ai_state.id

  posix_user {
    uid = 999
    gid = 999
  }

  root_directory {
    path = "/worker"

    creation_info {
      owner_uid   = 999
      owner_gid   = 999
      permissions = "0700"
    }
  }

  tags = {
    Name    = "${local.ecs_name}-ai-worker-state"
    Service = "ai"
  }
}
