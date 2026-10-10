variable "name" {
  description = "Name prefix for resources, e.g. ophub-prod."
  type        = string
}

variable "web_bucket_name" {
  description = "Globally unique name of the private S3 bucket holding the React build."
  type        = string
}

variable "api_origin_domain_name" {
  description = "Public DNS name of the API host (CloudFront connects to it over HTTP :80)."
  type        = string
}

variable "origin_verify_secret" {
  description = "Value of the X-Origin-Verify header CloudFront adds to API requests; the API proxy rejects requests without it."
  type        = string
  sensitive   = true
}
