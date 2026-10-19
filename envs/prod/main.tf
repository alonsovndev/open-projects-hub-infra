locals {
  name                 = "ophub-prod"
  ssm_parameter_prefix = "/ophub/prod"
}

data "cloudflare_ip_ranges" "edge" {}

module "compute" {
  source = "../../modules/compute"

  name                 = local.name
  instance_type        = var.instance_type
  ssm_parameter_prefix = local.ssm_parameter_prefix
  edge_ipv4_cidrs      = data.cloudflare_ip_ranges.edge.ipv4_cidrs
}

# Proxied: Cloudflare terminates the public TLS and is the only client the security group admits.
resource "cloudflare_dns_record" "api" {
  zone_id = var.cloudflare_zone_id
  name    = var.api_hostname
  type    = "A"
  content = module.compute.public_ip
  ttl     = 1 # automatic, required when proxied
  proxied = true
  comment = "Open Projects Hub API (managed by Terraform)"
}

module "deploy" {
  source = "../../modules/deploy"

  name         = local.name
  github_owner = var.github_owner
  api_repo     = var.api_repo
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
