output "deploy_document_name" {
  description = "SSM document that deploys a release tag on the host (started by scripts/deploy-release.sh in the backend repo)."
  value       = aws_ssm_document.deploy.name
}
