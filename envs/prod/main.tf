data "aws_caller_identity" "current" {}

locals {
  name                 = "ophub-prod"
  account_id           = data.aws_caller_identity.current.account_id
  ssm_parameter_prefix = "/ophub/prod"
}

module "compute" {
  source = "../../modules/compute"

  name                 = local.name
  instance_type        = var.instance_type
  ssm_parameter_prefix = local.ssm_parameter_prefix
}

module "frontend" {
  source = "../../modules/frontend"

  name                   = local.name
  web_bucket_name        = "${local.name}-web-${local.account_id}"
  api_origin_domain_name = module.compute.origin_domain_name
  origin_verify_secret   = random_password.origin_verify.result
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  name             = local.name
  github_owner     = var.github_owner
  api_repo         = var.api_repo
  web_repo         = var.web_repo
  api_instance_arn = module.compute.instance_arn
  web_bucket_arn   = module.frontend.web_bucket_arn
  distribution_arn = module.frontend.distribution_arn
}

resource "aws_budgets_budget" "cash_spend" {
  name         = "${local.name}-cash-spend"
  budget_type  = "COST"
  limit_amount = "1"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}

# Credits hide real usage in the budget above; this one tracks gross usage so
# credit burn is visible before the Free Plan window ends.
resource "aws_budgets_budget" "gross_usage" {
  name         = "${local.name}-gross-usage"
  budget_type  = "COST"
  limit_amount = "20"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit = false
    include_refund = false
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}
