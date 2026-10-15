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

variable "instance_type" {
  description = "API host instance type (must be Free Plan eligible)."
  type        = string
  default     = "t3.micro"
}

variable "cloudflare_zone_id" {
  description = "ID of the Cloudflare zone that holds the API hostname (zone Overview page, API section)."
  type        = string
}

variable "api_hostname" {
  description = "Public hostname of the API, one label under the Cloudflare zone (so the free Universal certificate covers it), e.g. api-oph.example.com."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.api_hostname))
    error_message = "Use a lowercase fully qualified hostname such as api-oph.example.com."
  }
}

variable "frontend_origin" {
  description = "Origin of the web app (scheme and host, no path), allowed by CORS and used for email links."
  type        = string

  validation {
    condition     = can(regex("^https://[a-z0-9.-]+$", var.frontend_origin))
    error_message = "Use an https origin without a trailing slash, e.g. https://oph.example.com."
  }
}
