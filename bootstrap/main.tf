terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "region" {
  description = "AWS region for the Terraform state bucket."
  type        = string
  default     = "us-east-1"
}

variable "github_owner" {
  description = "GitHub user or organization that owns the infrastructure repository."
  type        = string
  default     = "alonsovndev"
}

variable "infra_repo" {
  description = "Infrastructure repository whose destroy workflow assumes the destroy role."
  type        = string
  default     = "open-projects-hub-infra"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project   = "open-projects-hub"
      managedBy = "terraform"
      stack     = "bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  state_bucket_name = "ophub-tfstate-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_tls_only.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}

# Account-wide singleton. It lives here, not in envs/prod, so the destroy role keeps working
# after envs/prod is destroyed; envs/prod only looks it up.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Role for .github/workflows/destroy.yml. It lives in bootstrap/ so destroying envs/prod cannot
# delete the role that is running the destroy. Only the "destroy" GitHub Environment (required
# reviewer) can assume it, and its policy can read, modify and delete envs/prod resources but
# never create them.
data "aws_iam_policy_document" "destroy_trust" {
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
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.infra_repo}:environment:destroy"]
    }
  }
}

resource "aws_iam_role" "terraform_destroy" {
  name                 = "ophub-terraform-destroy"
  assume_role_policy   = data.aws_iam_policy_document.destroy_trust.json
  max_session_duration = 7200 # headroom for a slow instance termination
}

data "aws_iam_policy_document" "terraform_destroy" {
  statement {
    sid       = "StateBucketList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "ProdStateAndLock"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/prod/*"]
  }

  statement {
    sid       = "Ec2ReadAndDelete"
    actions   = ["ec2:Describe*", "ec2:Get*"]
    resources = ["*"]
  }

  # Limited to the instance this stack tags (provider default_tags).
  statement {
    sid       = "Ec2ProdInstance"
    actions   = ["ec2:ModifyInstanceAttribute", "ec2:TerminateInstances"]
    resources = ["arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/environment"
      values   = ["prod"]
    }
  }

  statement {
    sid = "Ec2Delete"
    actions = [
      "ec2:DisassociateAddress",
      "ec2:ReleaseAddress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteManagedPrefixList",
      "ec2:DeleteTags",
    ]
    resources = ["*"]
  }

  statement {
    sid = "IamProdRolesAndProfile"
    actions = [
      "iam:Get*",
      "iam:List*",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:DeleteInstanceProfile",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ophub-prod-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/ophub-prod-*",
    ]
  }

  # The prod module finds the provider by URL, which lists all providers and reads each one.
  statement {
    sid       = "IamReadOidcProviders"
    actions   = ["iam:GetOpenIDConnectProvider"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/*"]
  }

  statement {
    sid       = "IamListProviders"
    actions   = ["iam:ListOpenIDConnectProviders"]
    resources = ["*"]
  }

  statement {
    sid = "SsmParametersReadAndDelete"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:ListTagsForResource",
      "ssm:DeleteParameter",
      "ssm:DeleteParameters",
    ]
    resources = ["arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/ophub/prod/*"]
  }

  statement {
    sid       = "SsmDescribeParameters"
    actions   = ["ssm:DescribeParameters"]
    resources = ["*"]
  }

  statement {
    sid       = "SsmPublicAmiParameter"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:*::parameter/aws/service/ami-amazon-linux-latest/*"]
  }

  statement {
    sid = "SsmDeployDocument"
    actions = [
      "ssm:DescribeDocument",
      "ssm:GetDocument",
      "ssm:DescribeDocumentPermission",
      "ssm:ListTagsForResource",
      "ssm:DeleteDocument",
    ]
    resources = ["arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:document/ophub-prod-*"]
  }

  statement {
    sid = "BudgetsReadAndDelete"
    actions = [
      "budgets:ViewBudget",
      "budgets:DescribeBudgetActionsForBudget",
      "budgets:ListTagsForResource",
      "budgets:DeleteBudget",
    ]
    resources = ["arn:aws:budgets::${data.aws_caller_identity.current.account_id}:budget/ophub-prod-*"]
  }
}

resource "aws_iam_role_policy" "terraform_destroy" {
  name   = "destroy-envs-prod"
  role   = aws_iam_role.terraform_destroy.id
  policy = data.aws_iam_policy_document.terraform_destroy.json
}

output "state_bucket_name" {
  description = "Bucket name to use in envs/*/backend.tf."
  value       = aws_s3_bucket.state.id
}

output "destroy_role_arn" {
  description = "Value for the DESTROY_ROLE_ARN repository variable of the infrastructure repository."
  value       = aws_iam_role.terraform_destroy.arn
}
