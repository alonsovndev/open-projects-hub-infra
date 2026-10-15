output "api_deploy_role_arn" {
  description = "Role ARN for the API repo deploy workflow."
  value       = aws_iam_role.api_deploy.arn
}

output "deploy_document_name" {
  description = "SSM document the API deploy workflow runs (must match SSM_DOCUMENT in its deploy.yml)."
  value       = aws_ssm_document.deploy.name
}
