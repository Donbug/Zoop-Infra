# Format-valid synthetic metadata only; this file cannot supply deployable inputs.
mock_provider "aws" {
  override_during = plan
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111122223333" }
  }
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-00000000000000001", map_public_ip_on_launch = false }
  }
  mock_data "aws_security_group" {
    defaults = { vpc_id = "vpc-00000000000000001" }
  }
  mock_data "aws_efs_file_system" {
    defaults = { id = "fs-00000000000000001", encrypted = true, arn = "arn:aws:elasticfilesystem:ap-northeast-2:111122223333:file-system/fs-00000000000000001" }
  }
  mock_data "aws_efs_access_point" {
    defaults = { file_system_id = "fs-00000000000000001", owner_id = "111122223333" }
  }
  mock_data "aws_ecs_cluster" {
    defaults = { arn = "arn:aws:ecs:ap-northeast-2:111122223333:cluster/zoop-dev" }
  }
  # Mocked computed JSON is only a schema fixture; assertions below inspect authored statements.
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::111122223333:role/synthetic" }
  }
  mock_resource "aws_secretsmanager_secret" {
    defaults = { arn = "arn:aws:secretsmanager:ap-northeast-2:111122223333:secret:synthetic-ABCDEF" }
  }
}

override_data {
  target = data.aws_ecr_repository.image["reader"]
  values = {
    arn            = "arn:aws:ecr:ap-northeast-2:111122223333:repository/synthetic-reader"
    repository_url = "111122223333.dkr.ecr.ap-northeast-2.amazonaws.com/synthetic-reader"
  }
}
override_data {
  target = data.aws_ecr_repository.image["operator"]
  values = {
    arn            = "arn:aws:ecr:ap-northeast-2:111122223333:repository/synthetic-operator"
    repository_url = "111122223333.dkr.ecr.ap-northeast-2.amazonaws.com/synthetic-operator"
  }
}
override_resource {
  target          = aws_efs_access_point.new["archive"]
  override_during = plan
  values          = { id = "fsap-00000000000000011" }
}
override_resource {
  target          = aws_efs_access_point.new["authority"]
  override_during = plan
  values          = { id = "fsap-00000000000000012" }
}
override_resource {
  target          = aws_efs_access_point.new["control"]
  override_during = plan
  values          = { id = "fsap-00000000000000013" }
}

override_resource {
  target          = aws_security_group.task["reader"]
  override_during = plan
  values          = { id = "sg-00000000000000011" }
}
override_resource {
  target          = aws_security_group.task["stage"]
  override_during = plan
  values          = { id = "sg-00000000000000012" }
}
override_resource {
  target          = aws_security_group.task["operator"]
  override_during = plan
  values          = { id = "sg-00000000000000013" }
}

variables {
  expected_account_id = "111122223333"
  aws_region          = "ap-northeast-2"
  existing = {
    vpc_id             = "vpc-00000000000000001"
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
    cluster_arn        = "arn:aws:ecs:ap-northeast-2:111122223333:cluster/zoop-dev"
    namespace_id       = "ns-synthetic"
    efs_id             = "fs-00000000000000001"
    efs_security_group = "sg-00000000000000001"
    rds_security_group = "sg-00000000000000002"
    access_points = {
      archive    = "fsap-00000000000000001"
      authority  = "fsap-00000000000000002"
      operations = "fsap-00000000000000003"
      artifacts  = "fsap-00000000000000004"
    }
  }
  images = {
    reader = {
      pin            = "111122223333.dkr.ecr.ap-northeast-2.amazonaws.com/synthetic-reader@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      repository_arn = "arn:aws:ecr:ap-northeast-2:111122223333:repository/synthetic-reader"
    }
    operator = {
      pin            = "111122223333.dkr.ecr.ap-northeast-2.amazonaws.com/synthetic-operator@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
      repository_arn = "arn:aws:ecr:ap-northeast-2:111122223333:repository/synthetic-operator"
    }
  }
  reader_python = "/opt/zoop/service/.venv/bin/python"
  database = {
    address         = "synthetic.aaaaaaaaaaaa.ap-northeast-2.rds.amazonaws.com"
    name            = "synthetic"
    credentials_arn = "arn:aws:secretsmanager:ap-northeast-2:111122223333:secret:synthetic-db-ABCDEF"
    csrf_secret_arn = "arn:aws:secretsmanager:ap-northeast-2:111122223333:secret:synthetic-csrf-ABCDEF"
    csrf_key_id     = "synthetic"
    kms_key_arns    = []
  }
  archive = {
    source_path     = "/mnt/zoop-ops/synthetic/archive.tar.gz"
    sha256          = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    manifest_path   = "/mnt/zoop-ops/synthetic/MANIFEST.json"
    manifest_sha256 = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  }
  authority = {
    inventory_path   = "/mnt/zoop-op69-authority/synthetic/source-contexts.json"
    inventory_sha256 = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
    deny_all_grants  = "/mnt/zoop-op69-authority/synthetic/deny-all.json"
    operator_sources = "/mnt/zoop-op69-authority/synthetic/operator-sources.json"
    principal        = "synthetic-reader"
  }
  profiles = {
    for name in ["existing2", "six", "three", "eu11"] : name => {
      registration_request = "/mnt/zoop-op69-control/${name}/synthetic-request.json"
      registration_result  = "/mnt/zoop-op69-control/${name}/synthetic-registration-result.json"
      bindings_selection   = "/mnt/zoop-op69-control/${name}/synthetic-selection.json"
      bindings_output      = "/mnt/zoop-op69-control/${name}/synthetic-bindings.json"
      bindings_result      = "/mnt/zoop-op69-control/${name}/synthetic-bindings-result.json"
    }
  }
}

run "observation_only_contract" {
  command = plan
  assert {
    condition     = length(aws_efs_access_point.new) == 3 && length(aws_ecs_service.reader) == 4 && length(aws_ecs_task_definition.register) == 4 && length(aws_service_discovery_service.reader) == 4 && length(aws_iam_role.execution) + length(aws_iam_role.task) == 6 && length(aws_security_group.task) == 3 && length(aws_secretsmanager_secret.new) == 2
    error_message = "The new-resource boundary must remain three APs, four readers/DNS/registers, six roles, three SGs and two containers."
  }
  assert {
    condition = alltrue([for name, service in aws_ecs_service.reader :
      service.desired_count == 0 && service.name == "zoop-dev-op69-reader-${name}" && !one(service.network_configuration).assign_public_ip && aws_service_discovery_service.reader[name].name == "op69-${name}"
    ])
    error_message = "Readers must start at desired zero with exact private names."
  }
  assert {
    condition = alltrue([for service in values(aws_service_discovery_service.reader) :
      one(service.health_check_custom_config).failure_threshold == 1
    ])
    error_message = "Reader discovery services must enable the ECS-managed custom health check explicitly."
  }
  assert {
    condition = (
      length(local.reader_mounts) == 5 && alltrue([for m in values(local.reader_mounts) : m.ro]) &&
      local.reader_mounts.old_archive.path == "/srv/zoop-ai-read/archive" && local.reader_mounts.old_authority.path == "/mnt/zoop-authority" &&
      local.stage_mounts.operations.ro && !local.stage_mounts.archive.ro &&
      toset([for name, m in local.operator_mounts : name if !m.ro]) == toset(["control", "artifacts"])
    )
    error_message = "The reader/stage/operator RO/RW mount boundary changed."
  }
  assert {
    condition = alltrue([for name, c in local.reader_containers :
      c.user == "0:0" && c.readonlyRootFilesystem && c.entryPoint[0] == var.reader_python && c.entryPoint[3] == file("${path.module}/scripts/reader_bootstrap.py") &&
      local.reader_config[name].scratch_root == "/var/lib/zoop-op69/${name}" &&
      length([for key in keys(local.reader_environment[name]) : key if can(regex("ROUND|CHAT|LIVE|MODEL|HANDOFF|REPLAY|PROFILE|API_KEY|INGESTION_STATE|SERVICE_SOURCES", key))]) == 0 &&
      local.reader_environment[name].ZOOP_AI_SERVICE_OBSERVATION_SOURCE_CONTEXTS_SHA256 == var.authority.inventory_sha256
    ])
    error_message = "Observation readers must embed the sanitizer, use private UID0 scratch and omit forbidden configuration."
  }
  assert {
    condition = (
      alltrue([for s in data.aws_iam_policy_document.efs["reader"].statement : toset(s.actions) == toset(["elasticfilesystem:ClientMount"])]) &&
      length(local.ap_arns.reader.ro) == 5 && length(local.ap_arns.reader.rw) == 0 && length(local.ap_arns.stage.rw) == 1 && length(local.ap_arns.operator.rw) == 2 &&
      alltrue(flatten([for d in values(data.aws_iam_policy_document.efs) : [for s in d.statement : !contains(s.actions, "elasticfilesystem:ClientRootAccess") && toset(s.resources) == toset([local.fs_arn])]])) &&
      length(local.execution_secrets.stage) == 0 && length(local.execution_secrets.reader) == 1 && length(local.execution_secrets.operator) == 3
    )
    error_message = "Authored IAM statements must constrain EFS and runtime secret access. Mock JSON is not policy evaluation."
  }
  assert {
    condition = alltrue([for name in keys(var.profiles) :
      local.registration_environment[name].ZOOP_DOCUMENT_IMPORT_ENABLED == "true" && local.registration_environment[name].ZOOP_DOCUMENT_BINDINGS_ENABLED == "false" &&
      local.bindings_environment[name].ZOOP_DOCUMENT_IMPORT_ENABLED == "false" && local.bindings_environment[name].ZOOP_DOCUMENT_BINDINGS_ENABLED == "true" &&
      local.bindings_environment[name].ZOOP_DOCUMENT_BINDINGS_SCOPE == "available" &&
      local.bindings_environment[name].ZOOP_DOCUMENT_BINDINGS_SELECTION == var.profiles[name].bindings_selection &&
      local.operator_safety.SPRING_FLYWAY_ENABLED == "false" && local.operator_safety.SPRING_JPA_HIBERNATE_DDL_AUTO == "validate" && local.operator_safety.SPRING_SQL_INIT_MODE == "never" && local.operator_safety.ZOOP_GRAPH_SNAPSHOT_SOURCE == "none" &&
      !contains(keys(local.registration_environment[name]), "ZOOP_INGESTION_CLI") && !contains(keys(local.bindings_environment[name]), "ZOOP_DOCUMENT_IMPORT_REQUEST")
    ])
    error_message = "Registration and reviewed override export must be separate non-web safe processes with unused CLI settings unset."
  }
  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.reader.from_port == 8000 && aws_vpc_security_group_ingress_rule.reader.referenced_security_group_id == aws_security_group.task["operator"].id &&
      length(aws_vpc_security_group_ingress_rule.efs) == 3 && aws_vpc_security_group_ingress_rule.database.from_port == 5432 &&
      local.stage_container.user == "0:0" && local.stage_container.readonlyRootFilesystem && local.stage_container.entryPoint[3] == file("${path.module}/scripts/stage_operational69.py")
    )
    error_message = "SG rules and embedded stage executable must remain scoped."
  }
}

run "reject_unpinned_images" {
  command = plan
  variables {
    images = {
      reader   = { pin = "synthetic:latest", repository_arn = "arn:aws:ecr:ap-northeast-2:111122223333:repository/synthetic-reader" }
      operator = { pin = "synthetic:latest", repository_arn = "arn:aws:ecr:ap-northeast-2:111122223333:repository/synthetic-operator" }
    }
  }
  expect_failures = [var.images]
}

run "reject_unknown_interpreter" {
  command = plan
  variables {
    reader_python = "/usr/bin/python"
  }
  expect_failures = [var.reader_python]
}

run "reject_wrong_account" {
  command = plan
  variables {
    expected_account_id = "999988887777"
  }
  expect_failures = [data.aws_efs_file_system.existing, data.aws_efs_access_point.existing]
}

run "complete_handoff_revision" {
  command = plan
  variables {
    profiles = {
      for name in ["existing2", "six", "three", "eu11"] : name => {
        registration_request = "/mnt/zoop-op69-control/${name}/synthetic-request.json"
        registration_result  = "/mnt/zoop-op69-control/${name}/synthetic-registration-result.json"
        bindings_selection   = "/mnt/zoop-op69-control/${name}/synthetic-selection.json"
        bindings_output      = "/mnt/zoop-op69-control/${name}/synthetic-bindings.json"
        bindings_result      = "/mnt/zoop-op69-control/${name}/synthetic-bindings-result.json"
        handoff = {
          root                   = "/srv/zoop-op69/archive/operational69-20261103-v1/payload/${name}/handoff"
          canonical              = "/mnt/zoop-op69-control/${name}/canonical.json"
          decisions              = "/mnt/zoop-op69-control/${name}/decisions.json"
          frozen_bindings        = "/srv/zoop-op69/archive/operational69-20261103-v1/payload/${name}/frozen-bindings.json"
          frozen_bindings_sha256 = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
          exports                = "/mnt/zoop-op69-control/${name}/exports.json"
          handoff_id             = "synthetic-${name}"
          manifest_digest        = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
          bundle_digest          = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
          target_bindings        = "/mnt/zoop-op69-control/${name}/synthetic-bindings.json"
          selected_rows_sha256   = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        }
      }
    }
  }
  assert {
    condition = alltrue([for name, env in local.reader_environment :
      env.ZOOP_AI_SERVICE_HANDOFF_SOURCE_CONTEXTS == env.ZOOP_AI_SERVICE_OBSERVATION_SOURCE_CONTEXTS &&
      env.ZOOP_AI_SERVICE_HANDOFF_SOURCE_CONTEXTS_SHA256 == env.ZOOP_AI_SERVICE_OBSERVATION_SOURCE_CONTEXTS_SHA256 &&
      length([for key in keys(env) : key if can(regex("HANDOFF", key))]) == 8 &&
      env.ZOOP_AI_SERVICE_HANDOFF_BINDINGS == var.profiles[name].handoff.frozen_bindings
    ])
    error_message = "Handoff must be complete, pin the same inventory, and keep the frozen bindings path."
  }
}
