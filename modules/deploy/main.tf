# The deploy command can only run this document, so it cannot become arbitrary shell on the host.
# The tag pattern keeps the parameter from carrying commands.
resource "aws_ssm_document" "deploy" {
  name            = "${var.name}-deploy"
  document_type   = "Command"
  document_format = "JSON"
  target_type     = "/AWS::EC2::Instance"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Deploy a tagged API release on the host"
    parameters = {
      tag = {
        type           = "String"
        description    = "Release tag, e.g. v1.2.3"
        allowedPattern = "^v[0-9]+\\.[0-9]+\\.[0-9]+$"
      }
    }
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "deploy"
      inputs = {
        timeoutSeconds = "600"
        runCommand = [
          "set -eu",
          "mkdir -p /opt/ophub",
          "curl -fsSL https://raw.githubusercontent.com/${var.github_owner}/${var.api_repo}/{{ tag }}/deploy/deploy.sh -o /opt/ophub/deploy.sh",
          "bash /opt/ophub/deploy.sh {{ tag }}",
        ]
      }
    }]
  })
}
