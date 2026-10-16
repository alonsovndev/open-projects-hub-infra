variable "name" {
  description = "Name prefix for resources, e.g. ophub-prod."
  type        = string
}

variable "github_owner" {
  description = "GitHub user or organization that owns the repositories."
  type        = string
}

variable "api_repo" {
  description = "Backend repository name allowed to deploy the API."
  type        = string
}

variable "api_repo_subject" {
  description = "OIDC subject prefix of the backend repository, as GitHub signs it (repo:OWNER@ID/REPO@ID with immutable subjects)."
  type        = string
}

variable "allowed_refs" {
  description = "Git refs allowed to assume the deploy role (StringLike patterns)."
  type        = list(string)
  default     = ["refs/tags/v*"]
}

variable "api_instance_arn" {
  description = "ARN of the EC2 instance the deploy role may run SSM commands on."
  type        = string
}
