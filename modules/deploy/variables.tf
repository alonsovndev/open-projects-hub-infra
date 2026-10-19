variable "name" {
  description = "Name prefix for resources, e.g. ophub-prod."
  type        = string
}

variable "github_owner" {
  description = "GitHub user or organization that owns the backend repository."
  type        = string
}

variable "api_repo" {
  description = "Backend repository whose tagged deploy script the host runs."
  type        = string
}
