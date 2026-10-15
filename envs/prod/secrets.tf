resource "random_password" "secret_key" {
  length  = 64
  special = false
}

# Alphanumeric only: the API builds the asyncpg URL without URL-encoding.
resource "random_password" "postgres" {
  length  = 32
  special = false
}

resource "random_bytes" "api_key_encryption" {
  length = 32
}

locals {
  generated_secrets = {
    SECRET_KEY             = random_password.secret_key.result
    POSTGRES_PASSWORD      = random_password.postgres.result
    API_KEY_ENCRYPTION_KEY = random_bytes.api_key_encryption.base64
  }

  manual_secrets = [
    "SMTP_HOST",
    "SMTP_USERNAME",
    "SMTP_PASSWORD",
    "SMTP_FROM_ADDRESS",
    "GEMINI_API_KEY",
    "SENTRY_DSN",
  ]
}

resource "aws_ssm_parameter" "generated" {
  for_each = toset(["SECRET_KEY", "POSTGRES_PASSWORD", "API_KEY_ENCRYPTION_KEY"])

  name  = "${local.ssm_parameter_prefix}/${each.key}"
  type  = "SecureString"
  value = local.generated_secrets[each.key]

  # Rotating API_KEY_ENCRYPTION_KEY makes every stored user API key undecryptable.
  lifecycle {
    ignore_changes = [value]
  }
}

# Real values are set by hand (aws ssm put-parameter --overwrite); the app
# treats "N/A" as unset.
resource "aws_ssm_parameter" "manual" {
  for_each = toset(local.manual_secrets)

  name  = "${local.ssm_parameter_prefix}/${each.key}"
  type  = "SecureString"
  value = "N/A"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "api_host" {
  name  = "${local.ssm_parameter_prefix}/API_HOST"
  type  = "String"
  value = var.api_hostname
}

resource "aws_ssm_parameter" "frontend_base_url" {
  name  = "${local.ssm_parameter_prefix}/FRONTEND_BASE_URL"
  type  = "String"
  value = var.frontend_origin
}

resource "aws_ssm_parameter" "cors_origins" {
  name  = "${local.ssm_parameter_prefix}/CORS_ORIGINS"
  type  = "String"
  value = var.frontend_origin
}

# The web app lives on another origin, so the browser session cookie needs credentialed CORS.
resource "aws_ssm_parameter" "cors_allow_credentials" {
  name  = "${local.ssm_parameter_prefix}/CORS_ALLOW_CREDENTIALS"
  type  = "String"
  value = "true"
}
