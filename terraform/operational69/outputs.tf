output "access_points" {
  value = { for name, ap in aws_efs_access_point.new : name => { id = ap.id, arn = ap.arn } }
}

output "secret_containers" {
  value = { for name, secret in aws_secretsmanager_secret.new : name => secret.arn }
}

output "roles" {
  value = {
    execution = { for name, role in aws_iam_role.execution : name => role.arn }
    task      = { for name, role in aws_iam_role.task : name => role.arn }
  }
}

output "private_network" {
  value = {
    cluster_arn        = var.existing.cluster_arn
    subnet_ids         = sort(tolist(var.existing.private_subnet_ids))
    security_group_ids = { for name, sg in aws_security_group.task : name => sg.id }
    assign_public_ip   = false
  }
}

output "reader_services" {
  value = { for name in local.profiles : name => {
    service         = aws_ecs_service.reader[name].name
    task_definition = aws_ecs_task_definition.reader[name].arn
    endpoint        = "http://op69-${name}.zoop-dev.internal:8000"
  } }
}

output "stage_task_definition" {
  value = aws_ecs_task_definition.stage.arn
}

output "registration_task_definitions" {
  value = { for name, task in aws_ecs_task_definition.register : name => task.arn }
}

output "bindings_export_overrides" {
  description = "Review and approve each complete override before a separate export-only process; not executed by Terraform."
  value = { for name in local.profiles : name => {
    containerOverrides = [{ name = "operator", command = local.bindings_command[name] }]
  } }
}

output "executable_sha256" {
  value = {
    reader = filesha256("${path.module}/scripts/reader_bootstrap.py")
    stage  = filesha256("${path.module}/scripts/stage_operational69.py")
  }
}
