output "api_url" {
  description = "Public URL of the API (the API_URL for scripts/deploy-release.sh in the api repo, and VITE_API_BASE_URL of the web build)."
  value       = "https://${var.api_hostname}"
}

output "host_public_ip" {
  description = "Elastic IP of the host (origin of the Cloudflare DNS record)."
  value       = module.compute.public_ip
}

output "api_instance_id" {
  description = "EC2 instance ID of the API host (informational; the deploy script finds the host by its Name tag)."
  value       = module.compute.instance_id
}

output "ssm_parameter_prefix" {
  description = "SSM path prefix holding the API runtime config."
  value       = local.ssm_parameter_prefix
}

output "deploy_document_name" {
  description = "SSM document that deploys a release tag on the host."
  value       = module.deploy.deploy_document_name
}
