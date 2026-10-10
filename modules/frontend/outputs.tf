output "distribution_id" {
  description = "CloudFront distribution ID (cache invalidation target)."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = aws_cloudfront_distribution.this.arn
}

output "domain_name" {
  description = "Public *.cloudfront.net domain serving the web app and /v1/* API."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "web_bucket_name" {
  description = "S3 bucket receiving the React build."
  value       = aws_s3_bucket.web.id
}

output "web_bucket_arn" {
  description = "S3 bucket ARN."
  value       = aws_s3_bucket.web.arn
}
