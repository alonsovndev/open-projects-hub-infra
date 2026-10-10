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

variable "web_repo" {
  description = "Frontend repository name allowed to deploy the web app."
  type        = string
}

variable "allowed_refs" {
  description = "Git refs allowed to assume the deploy roles (StringLike patterns)."
  type        = list(string)
  default     = ["refs/tags/v*"]
}

variable "api_instance_arn" {
  description = "ARN of the EC2 instance the API role may run SSM commands on."
  type        = string
}

variable "web_bucket_arn" {
  description = "ARN of the S3 bucket the web role may sync into."
  type        = string
}

variable "distribution_arn" {
  description = "ARN of the CloudFront distribution the web role may invalidate."
  type        = string
}
