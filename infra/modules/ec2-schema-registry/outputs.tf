output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.schema_registry.id
}

output "public_ip" {
  description = "Elastic IP (public IP) of the Schema Registry instance"
  value       = aws_eip.schema_registry.public_ip
}

output "schema_registry_url" {
  description = "Schema Registry URL (public, for laptop/Postman)"
  value       = "http://${aws_eip.schema_registry.public_ip}:8081"
}

output "schema_registry_private_url" {
  description = "Schema Registry URL (private, for Lambdas in VPC)"
  value       = "http://${aws_instance.schema_registry.private_ip}:8081"
}

output "security_group_id" {
  description = "Security group ID of the Schema Registry instance"
  value       = aws_security_group.schema_registry.id
}
