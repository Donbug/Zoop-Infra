locals {
  reader_environment = {
    for name, p in var.profiles : name => merge({
      ZOOP_AI_SERVICE_STATE_DIR                          = "/var/lib/zoop-op69/${name}/service"
      ZOOP_AI_WORKER_STATE_DIR                           = "/var/lib/zoop-op69/${name}/worker"
      ZOOP_STATE_DIR                                     = "/var/lib/zoop-op69/${name}/app"
      ZOOP_AI_SERVICE_WORKER_COMMAND                     = "/opt/zoop/worker/.venv/bin/zoop-ai"
      ZOOP_AI_SERVICE_INGESTION_COMMAND                  = "/opt/zoop/pipeline/.venv/bin/zoop-ai-ingest"
      ZOOP_AI_SERVICE_GRANTS                             = var.authority.deny_all_grants
      ZOOP_AI_SERVICE_HOST                               = "0.0.0.0"
      ZOOP_AI_SERVICE_PORT                               = "8000"
      ZOOP_AI_SERVICE_OBSERVATION_SOURCE_CONTEXTS        = var.authority.inventory_path
      ZOOP_AI_SERVICE_OBSERVATION_SOURCE_CONTEXTS_SHA256 = var.authority.inventory_sha256
      }, p.handoff == null ? {} : {
      ZOOP_AI_SERVICE_HANDOFF_COMMAND                = "/opt/zoop/pipeline/.venv/bin/zoop-ai-handoff"
      ZOOP_AI_HANDOFF_STATE_DIR                      = p.handoff.root
      ZOOP_AI_SERVICE_HANDOFF_CANONICAL              = p.handoff.canonical
      ZOOP_AI_SERVICE_HANDOFF_DECISIONS              = p.handoff.decisions
      ZOOP_AI_SERVICE_HANDOFF_BINDINGS               = p.handoff.frozen_bindings
      ZOOP_AI_SERVICE_HANDOFF_EXPORTS                = p.handoff.exports
      ZOOP_AI_SERVICE_HANDOFF_SOURCE_CONTEXTS        = var.authority.inventory_path
      ZOOP_AI_SERVICE_HANDOFF_SOURCE_CONTEXTS_SHA256 = var.authority.inventory_sha256
    })
  }
  reader_config = {
    for name, p in var.profiles : name => {
      environment  = local.reader_environment[name]
      principal    = var.authority.principal
      scratch_root = "/var/lib/zoop-op69/${name}"
      handoff = p.handoff == null ? null : {
        target_bindings      = p.handoff.target_bindings
        selection            = p.bindings_selection
        frozen_sha256        = p.handoff.frozen_bindings_sha256
        selected_rows_sha256 = p.handoff.selected_rows_sha256
        handoff_id           = p.handoff.handoff_id
        manifest_digest      = p.handoff.manifest_digest
        bundle_digest        = p.handoff.bundle_digest
      }
    }
  }
  reader_containers = {
    for name in local.profiles : name => {
      name                   = "reader"
      image                  = var.images.reader.pin
      user                   = "0:0"
      essential              = true
      readonlyRootFilesystem = true
      entryPoint             = [var.reader_python, "-B", "-c", file("${path.module}/scripts/reader_bootstrap.py")]
      command                = [jsonencode(local.reader_config[name])]
      environment            = []
      secrets                = [{ name = "ZOOP_AI_SERVICE_PRINCIPALS", valueFrom = aws_secretsmanager_secret.new["reader-principals"].arn }]
      portMappings           = [{ containerPort = 8000, protocol = "tcp" }]
      mountPoints = concat([for key, m in local.reader_mounts : { sourceVolume = key, containerPath = m.path, readOnly = m.ro }], [
        { sourceVolume = "scratch", containerPath = "/var/lib/zoop-op69", readOnly = false },
        { sourceVolume = "tmp", containerPath = "/tmp", readOnly = false }
      ])
      linuxParameters = { initProcessEnabled = true }
      healthCheck = {
        command     = ["CMD", var.reader_python, "-B", "-c", "import socket; socket.create_connection(('127.0.0.1',8000),3).close()"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.task["reader"].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = name
        }
      }
    }
  }
}

resource "aws_ecs_task_definition" "reader" {
  for_each                 = local.profiles
  family                   = "zoop-dev-op69-reader-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.execution["reader"].arn
  task_role_arn            = aws_iam_role.task["reader"].arn
  container_definitions    = jsonencode([local.reader_containers[each.key]])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  dynamic "volume" {
    for_each = local.reader_mounts
    content {
      name = volume.key
      efs_volume_configuration {
        file_system_id     = var.existing.efs_id
        root_directory     = "/"
        transit_encryption = "ENABLED"
        authorization_config {
          access_point_id = volume.value.ap
          iam             = "ENABLED"
        }
      }
    }
  }
  volume {
    name = "scratch"
  }
  volume {
    name = "tmp"
  }
  depends_on = [aws_iam_role_policy.execution, aws_iam_role_policy.efs]
}

resource "aws_service_discovery_service" "reader" {
  for_each = local.profiles
  name     = "op69-${each.key}"
  dns_config {
    namespace_id   = var.existing.namespace_id
    routing_policy = "MULTIVALUE"
    dns_records {
      ttl  = 10
      type = "A"
    }
  }
  health_check_custom_config {}
}

resource "aws_ecs_service" "reader" {
  for_each         = local.profiles
  name             = "zoop-dev-op69-reader-${each.key}"
  cluster          = data.aws_ecs_cluster.existing.arn
  task_definition  = aws_ecs_task_definition.reader[each.key].arn
  desired_count    = 0
  launch_type      = "FARGATE"
  platform_version = "1.4.0"
  network_configuration {
    subnets          = sort(tolist(var.existing.private_subnet_ids))
    security_groups  = [aws_security_group.task["reader"].id]
    assign_public_ip = false
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  service_registries {
    registry_arn = aws_service_discovery_service.reader[each.key].arn
  }
  depends_on = [aws_vpc_security_group_ingress_rule.efs, aws_vpc_security_group_egress_rule.efs, data.aws_subnet.private]
}
