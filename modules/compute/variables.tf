variable "name" {
  description = "Name prefix for resources, e.g. ophub-prod."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. Must be Free Plan eligible to stay inside the credits."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_gb" {
  description = "Root gp3 volume size in GB. Postgres data lives here."
  type        = number
  default     = 20
}

variable "ssm_parameter_prefix" {
  description = "SSM Parameter Store path prefix the instance may read, e.g. /ophub/prod."
  type        = string
}

variable "compose_version" {
  description = "Docker Compose v2 release installed as a CLI plugin."
  type        = string
  default     = "v2.29.7"
}

variable "edge_ipv4_cidrs" {
  description = "IPv4 ranges allowed to reach HTTPS on the host (Cloudflare's edge)."
  type        = list(string)

  validation {
    condition     = length(var.edge_ipv4_cidrs) > 0 && length(var.edge_ipv4_cidrs) <= 20
    error_message = "Provide 1 to 20 CIDR blocks (the prefix list holds at most 20)."
  }
}
