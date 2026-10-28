ephemeral "random_password" "ai_client_token" {
  length  = 43
  special = false
}

locals {
  ai_service_principals = jsonencode([
    {
      principal = "zoop-api"

      tokenSha256 = [
        sha256(ephemeral.random_password.ai_client_token.result)
      ]

      scopes = [
        "analysis.submit",
        "analysis.read",
        "analysis.cancel",
        "analysis.recover"
      ]
    }
  ])

  ai_auth_secret_value = jsonencode({
    client_token       = ephemeral.random_password.ai_client_token.result
    service_principals = local.ai_service_principals
  })
}

resource "aws_secretsmanager_secret" "ai_auth" {
  name                    = "${local.ecs_name}/ai/auth"
  description             = "Authentication material shared by the Dev API and AI service"
  recovery_window_in_days = 0

  tags = {
    Name    = "${local.ecs_name}-ai-auth"
    Service = "ai"
  }
}

resource "aws_secretsmanager_secret_version" "ai_auth" {
  secret_id = aws_secretsmanager_secret.ai_auth.id

  secret_string_wo         = local.ai_auth_secret_value
  secret_string_wo_version = 1
}
