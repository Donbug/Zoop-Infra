ephemeral "random_password" "api_csrf_key" {
  length  = 43
  special = false
}

resource "aws_secretsmanager_secret" "api_csrf" {
  name                    = "${local.ecs_name}/api/csrf"
  description             = "CSRF key ring for the Dev API service"
  recovery_window_in_days = 0

  tags = {
    Name    = "${local.ecs_name}-api-csrf"
    Service = "api"
  }
}

resource "aws_secretsmanager_secret_version" "api_csrf" {
  secret_id = aws_secretsmanager_secret.api_csrf.id

  secret_string_wo         = "dev-v1=${ephemeral.random_password.api_csrf_key.result}"
  secret_string_wo_version = 1
}