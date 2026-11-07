locals {
  operator_safety = {
    DB_URL                                  = "jdbc:postgresql://${var.database.address}:5432/${var.database.name}"
    ZOOP_AUTH_CSRF_ACTIVE_KEY_ID            = var.database.csrf_key_id
    SPRING_MAIN_WEB_APPLICATION_TYPE        = "none"
    SPRING_FLYWAY_ENABLED                   = "false"
    SPRING_JPA_HIBERNATE_DDL_AUTO           = "validate"
    SPRING_SQL_INIT_MODE                    = "never"
    ZOOP_GRAPH_SNAPSHOT_SOURCE              = "none"
    ZOOP_GRAPH_HANDOFF_IMPORT_ENABLED       = "false"
    ZOOP_GRAPH_AUTO_ACTIVATION_ENABLED      = "false"
    ZOOP_GRAPH_ROUND_ENABLED                = "false"
    ZOOP_GRAPH_ROUND_COMMANDS_ENABLED       = "false"
    ZOOP_GRAPH_ROUND_PREPARE_ENABLED        = "false"
    ZOOP_ANALYSIS_ANALYZE_PLAN_ENABLED      = "false"
    ZOOP_DOCUMENT_ANALYSIS_ENABLED          = "false"
    ZOOP_GRAPH_DELIVERY_SEAL_ENABLED        = "false"
    ZOOP_GRAPH_DELIVERY_INSTALL_ENABLED     = "false"
    ZOOP_DISCLOSURE_EXCLUSION_ENABLED       = "false"
    ZOOP_CHAT_QUESTIONS_ENABLED             = "false"
    ZOOP_CHAT_APPROVED_DOCS_ENABLED         = "false"
    ZOOP_CHAT_EXECUTOR_ENABLED              = "false"
    ZOOP_CHAT_MCP_ENABLED                   = "false"
    ZOOP_CHAT_AGENT_ENABLED                 = "false"
    ZOOP_CHAT_WEB_ENABLED                   = "false"
    ZOOP_AI_CLIENT_ENABLED                  = "false"
    ZOOP_AI_CHAT_CLIENT_ENABLED             = "false"
    ZOOP_AI_EXTRACTION_CLIENT_ENABLED       = "false"
    ZOOP_AI_RELATION_CLIENT_ENABLED         = "false"
    ZOOP_AI_HANDOFF_READ_CLIENT_ENABLED     = "false"
    ZOOP_AI_HANDOFF_EXPOSURE_CLIENT_ENABLED = "false"
    ZOOP_AI_PLAN_ADMISSION_CLIENT_ENABLED   = "false"
    ZOOP_AI_ROUND_CLIENT_ENABLED            = "false"
    ZOOP_DOCUMENT_READ_INGESTION_SOURCES    = var.authority.operator_sources
    ZOOP_DOCUMENT_READ_ARTIFACT_ROOT        = "/mnt/zoop-artifacts"
  }
  registration_environment = {
    for name, p in var.profiles : name => merge(local.operator_safety, {
      ZOOP_DOCUMENT_IMPORT_ENABLED               = "true"
      ZOOP_DOCUMENT_BINDINGS_ENABLED             = "false"
      ZOOP_DOCUMENT_IMPORT_REQUEST               = p.registration_request
      ZOOP_DOCUMENT_IMPORT_RESULT                = p.registration_result
      ZOOP_DOCUMENT_IMPORT_OBSERVATION_SOURCE    = "http"
      ZOOP_ARTIFACT_ROOT                         = "/mnt/zoop-artifacts"
      ZOOP_AI_OBSERVATION_EXPORT_CLIENT_ENABLED  = "true"
      ZOOP_AI_OBSERVATION_EXPORT_CLIENT_BASE_URL = "http://op69-${name}.zoop-dev.internal:8000"
      ZOOP_AI_PLAINTEXT_HTTP_HOSTS               = "op69-${name}.zoop-dev.internal"
    })
  }
  bindings_environment = {
    for name, p in var.profiles : name => merge(local.operator_safety, {
      ZOOP_DOCUMENT_IMPORT_ENABLED              = "false"
      ZOOP_DOCUMENT_BINDINGS_ENABLED            = "true"
      ZOOP_DOCUMENT_BINDINGS_OUTPUT             = p.bindings_output
      ZOOP_DOCUMENT_BINDINGS_RESULT             = p.bindings_result
      ZOOP_DOCUMENT_BINDINGS_SELECTION          = p.bindings_selection
      ZOOP_DOCUMENT_BINDINGS_SCOPE              = "available"
      ZOOP_AI_OBSERVATION_EXPORT_CLIENT_ENABLED = "false"
    })
  }
  java_command = ["/opt/java/openjdk/bin/java", "-jar", "/app/app.jar", "--spring.main.web-application-type=none", "--spring.config.import="]
  registration_command = {
    for name, env in local.registration_environment : name => concat(["register"], [for key in sort(keys(env)) : "${key}=${env[key]}"], local.java_command)
  }
  bindings_command = {
    for name, env in local.bindings_environment : name => concat(["bindings"], [for key in sort(keys(env)) : "${key}=${env[key]}"], local.java_command)
  }
  operator_entrypoint = ["/bin/sh", "-ec", <<-SHELL
    mode="$1"; shift
    case "$mode" in
      register) exec /usr/bin/env -i PATH=/opt/java/openjdk/bin:/usr/bin:/bin HOME=/tmp TMPDIR=/tmp DB_USERNAME="$DB_USERNAME" DB_PASSWORD="$DB_PASSWORD" ZOOP_AUTH_CSRF_KEYS="$ZOOP_AUTH_CSRF_KEYS" ZOOP_AI_OBSERVATION_EXPORT_CLIENT_TOKEN="$ZOOP_AI_OBSERVATION_EXPORT_CLIENT_TOKEN" "$@" ;;
      bindings) exec /usr/bin/env -i PATH=/opt/java/openjdk/bin:/usr/bin:/bin HOME=/tmp TMPDIR=/tmp DB_USERNAME="$DB_USERNAME" DB_PASSWORD="$DB_PASSWORD" ZOOP_AUTH_CSRF_KEYS="$ZOOP_AUTH_CSRF_KEYS" "$@" ;;
      *) exit 64 ;;
    esac
    SHELL
  , "operator"]
}

resource "aws_ecs_task_definition" "register" {
  for_each                 = local.profiles
  family                   = "zoop-dev-op69-register-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.execution["operator"].arn
  task_role_arn            = aws_iam_role.task["operator"].arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = jsonencode([{
    name                   = "operator"
    image                  = var.images.operator.pin
    user                   = "0:0"
    essential              = true
    readonlyRootFilesystem = true
    entryPoint             = local.operator_entrypoint
    command                = local.registration_command[each.key]
    environment            = []
    secrets = [
      { name = "DB_USERNAME", valueFrom = "${var.database.credentials_arn}:username::" },
      { name = "DB_PASSWORD", valueFrom = "${var.database.credentials_arn}:password::" },
      { name = "ZOOP_AUTH_CSRF_KEYS", valueFrom = var.database.csrf_secret_arn },
      { name = "ZOOP_AI_OBSERVATION_EXPORT_CLIENT_TOKEN", valueFrom = aws_secretsmanager_secret.new["api-reader-token"].arn }
    ]
    mountPoints = concat([for key, m in local.operator_mounts : { sourceVolume = key, containerPath = m.path, readOnly = m.ro }], [
      { sourceVolume = "tmp", containerPath = "/tmp", readOnly = false }
    ])
    linuxParameters = { initProcessEnabled = true }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.task["operator"].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = each.key
      }
    }
  }])
  dynamic "volume" {
    for_each = local.operator_mounts
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
    name = "tmp"
  }
  depends_on = [aws_iam_role_policy.execution, aws_iam_role_policy.efs]
}
