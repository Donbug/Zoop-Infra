resource "aws_secretsmanager_secret" "ai_collection" {
  name                    = "${local.ecs_name}/ai/collection"
  description             = "External API credentials for the Dev AI collection task"
  recovery_window_in_days = 0

  tags = {
    Name    = "${local.ecs_name}-ai-collection"
    Service = "ai-collection"
  }
}
