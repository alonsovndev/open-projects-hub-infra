variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "alert_email" {
  description = "Email receiving AWS Budgets cost alerts."
  type        = string
}

variable "github_owner" {
  description = "GitHub user or organization that owns the app repositories."
  type        = string
  default     = "alonsovndev"
}

variable "api_repo" {
  description = "Backend repository name."
  type        = string
  default     = "open-projects-hub-api"
}

variable "web_repo" {
  description = "Frontend repository name."
  type        = string
  default     = "open-projects-hub-web"
}

variable "instance_type" {
  description = "API host instance type (must be Free Plan eligible)."
  type        = string
  default     = "t3.micro"
}
