output "deploy_document_name" {
  description = "SSM document that deploys a release tag on the host (run by deploy.sh in the backend repo's docs)."
  value       = aws_ssm_document.deploy.name
}
