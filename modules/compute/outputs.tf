output "instance_id" {
  description = "EC2 instance ID (target of SSM Run Command)."
  value       = aws_instance.api.id
}

output "instance_arn" {
  description = "EC2 instance ARN."
  value       = aws_instance.api.arn
}

output "public_ip" {
  description = "Elastic IP of the host, the target of the Cloudflare DNS record."
  value       = aws_eip.api.public_ip
}
