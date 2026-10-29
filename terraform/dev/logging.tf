locals {
  ecs_log_groups = {
    api             = "/ecs/${local.ecs_name}/api"
    ai              = "/ecs/${local.ecs_name}/ai"
    "ai-collection" = "/ecs/${local.ecs_name}/ai-collection"
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  for_each = local.ecs_log_groups

  name              = each.value
  retention_in_days = 14

  tags = {
    Name    = each.value
    Service = each.key
  }
}