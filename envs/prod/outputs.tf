output "cloudfront_url" {
  description = "Public URL of the app; also the VITE_API_BASE_URL for the web build."
  value       = "https://${module.frontend.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "Distribution ID for cache invalidation in the web deploy workflow."
  value       = module.frontend.distribution_id
}

output "web_bucket_name" {
  description = "S3 bucket the web deploy workflow syncs dist/ into."
  value       = module.frontend.web_bucket_name
}

output "api_instance_id" {
  description = "EC2 instance ID targeted by the API deploy workflow (SSM Run Command)."
  value       = module.compute.instance_id
}

output "api_deploy_role_arn" {
  description = "Role ARN for the API repo GitHub Actions OIDC login."
  value       = module.github_oidc.api_deploy_role_arn
}

output "web_deploy_role_arn" {
  description = "Role ARN for the web repo GitHub Actions OIDC login."
  value       = module.github_oidc.web_deploy_role_arn
}

output "ssm_parameter_prefix" {
  description = "SSM path prefix holding the API runtime config."
  value       = local.ssm_parameter_prefix
}
