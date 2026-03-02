output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.kafka.id
}

output "public_ip" {
  description = "Elastic IP (public IP) of the Kafka instance"
  value       = aws_eip.kafka.public_ip
}

output "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers address (public)"
  value       = "${aws_eip.kafka.public_ip}:9092"
}

output "kafka_private_ip" {
  description = "Kafka private IP for same-VPC connections (e.g. Schema Registry)"
  value       = aws_instance.kafka.private_ip
}

output "security_group_id" {
  description = "Security group ID of the Kafka instance"
  value       = aws_security_group.ec2_kafka.id
}
