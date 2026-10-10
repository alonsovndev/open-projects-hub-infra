resource "random_password" "secret_key" {
  length  = 64
  special = false
}

# Alphanumeric only: the API builds the asyncpg URL without URL-encoding.
resource "random_password" "postgres" {
  length  = 32
  special = false
}

resource "random_password" "origin_verify" {
  length  = 40
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

  manual_secrets = ["SMTP_PASSWORD", "GEMINI_API_KEY", "SENTRY_DSN"]
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

# No ignore_changes: CloudFront sends random_password.origin_verify directly, so
# a rotation must reach the proxy through this parameter or /v1/* gets rejected.
resource "aws_ssm_parameter" "origin_verify" {
  name  = "${local.ssm_parameter_prefix}/ORIGIN_VERIFY"
  type  = "SecureString"
  value = random_password.origin_verify.result
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

resource "aws_ssm_parameter" "frontend_base_url" {
  name  = "${local.ssm_parameter_prefix}/FRONTEND_BASE_URL"
  type  = "String"
  value = "https://${module.frontend.domain_name}"
}

resource "aws_ssm_parameter" "cors_origins" {
  name  = "${local.ssm_parameter_prefix}/CORS_ORIGINS"
  type  = "String"
  value = "https://${module.frontend.domain_name}"
}
