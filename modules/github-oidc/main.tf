# The deploy role may only run this document, so a leaked workflow token cannot run
# arbitrary shell on the host. The tag pattern keeps the parameter from carrying commands.
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

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "api_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for ref in var.allowed_refs : "repo:${var.github_owner}/${var.api_repo}:ref:${ref}"]
    }
  }
}

data "aws_iam_policy_document" "web_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for ref in var.allowed_refs : "repo:${var.github_owner}/${var.web_repo}:ref:${ref}"]
    }
  }
}

resource "aws_iam_role" "api_deploy" {
  name               = "${var.name}-api-deploy"
  assume_role_policy = data.aws_iam_policy_document.api_trust.json
}

resource "aws_iam_role" "web_deploy" {
  name               = "${var.name}-web-deploy"
  assume_role_policy = data.aws_iam_policy_document.web_trust.json
}

data "aws_iam_policy_document" "api_deploy" {
  statement {
    sid     = "RunDeployScriptOnApiHost"
    actions = ["ssm:SendCommand"]
    resources = [
      var.api_instance_arn,
      aws_ssm_document.deploy.arn,
    ]
  }

  # These read actions do not support resource-level restrictions.
  statement {
    sid       = "ReadCommandResult"
    actions   = ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "api_deploy" {
  name   = "ssm-run-command"
  role   = aws_iam_role.api_deploy.id
  policy = data.aws_iam_policy_document.api_deploy.json
}

data "aws_iam_policy_document" "web_deploy" {
  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [var.web_bucket_arn]
  }

  statement {
    sid       = "SyncObjects"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.web_bucket_arn}/*"]
  }

  statement {
    sid       = "InvalidateCache"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [var.distribution_arn]
  }
}

resource "aws_iam_role_policy" "web_deploy" {
  name   = "s3-sync-and-invalidate"
  role   = aws_iam_role.web_deploy.id
  policy = data.aws_iam_policy_document.web_deploy.json
}
