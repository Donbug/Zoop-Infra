resource "aws_secretsmanager_secret" "first47_api_ai_token" {
  name                    = "${local.ecs_name}/first47/api-ai-token"
  description             = "Raw bearer token used by first47 API operators to read from the AI service"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name     = "${local.ecs_name}-first47-api-ai-token"
    Service  = "first47"
    Consumer = "api"
  }
}

resource "aws_secretsmanager_secret" "first47_ai_principals" {
  name                    = "${local.ecs_name}/first47/ai-principals"
  description             = "Read-only handoffer principal configuration for the first47 AI reader"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name     = "${local.ecs_name}-first47-ai-principals"
    Service  = "first47"
    Consumer = "ai"
  }
}
