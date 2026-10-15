output "api_url" {
  description = "Public URL of the API (value for the API_URL repository variable of the api repo, and VITE_API_BASE_URL of the web build)."
  value       = "https://${var.api_hostname}"
}

output "host_public_ip" {
  description = "Elastic IP of the host (origin of the Cloudflare DNS record)."
  value       = module.compute.public_ip
}

output "api_instance_id" {
  description = "EC2 instance ID targeted by the API deploy workflow (SSM Run Command)."
  value       = module.compute.instance_id
}

output "api_deploy_role_arn" {
  description = "Role ARN for the API repo GitHub Actions OIDC login."
  value       = module.github_oidc.api_deploy_role_arn
}

output "ssm_parameter_prefix" {
  description = "SSM path prefix holding the API runtime config."
  value       = local.ssm_parameter_prefix
}

output "deploy_document_name" {
  description = "SSM document run by the API deploy workflow."
  value       = module.github_oidc.deploy_document_name
}
