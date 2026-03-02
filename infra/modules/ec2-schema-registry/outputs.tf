output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.schema_registry.id
}

output "public_ip" {
  description = "Elastic IP (public IP) of the Schema Registry instance"
  value       = aws_eip.schema_registry.public_ip
}

output "schema_registry_url" {
  description = "Schema Registry URL"
  value       = "http://${aws_eip.schema_registry.public_ip}:8081"
}

output "security_group_id" {
  description = "Security group ID of the Schema Registry instance"
  value       = aws_security_group.schema_registry.id
}
