output "instance_id" {
  description = "EC2 instance ID (target of SSM Run Command)."
  value       = aws_instance.api.id
}

output "instance_arn" {
  description = "EC2 instance ARN."
  value       = aws_instance.api.arn
}

output "origin_domain_name" {
  description = "Public DNS name of the Elastic IP, used as the CloudFront API origin."
  value       = aws_eip.api.public_dns
}
