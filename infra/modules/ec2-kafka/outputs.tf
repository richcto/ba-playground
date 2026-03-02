output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.kafka.id
}

output "public_ip" {
  description = "Elastic IP (public IP) of the Kafka instance"
  value       = aws_eip.kafka.public_ip
}

output "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers address"
  value       = "${aws_eip.kafka.public_ip}:9092"
}
