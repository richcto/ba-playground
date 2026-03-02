# EC2 Kafka
output "kafka_instance_id" {
  description = "EC2 instance ID for Kafka"
  value       = module.ec2_kafka.instance_id
}

output "kafka_public_ip" {
  description = "Elastic IP of the Kafka instance"
  value       = module.ec2_kafka.public_ip
}

output "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers for producer/consumer configuration"
  value       = module.ec2_kafka.kafka_bootstrap_servers
}

# Lambdas
output "producer_api_url" {
  description = "Producer API Gateway URL"
  value       = module.producer.api_url
}

output "producer_function_name" {
  description = "Producer Lambda function name"
  value       = module.producer.function_name
}

output "consumer_function_name" {
  description = "Consumer Lambda function name"
  value       = module.consumer.function_name
}

# Schema Registry
output "schema_registry_url" {
  description = "Schema Registry URL"
  value       = module.ec2_schema_registry.schema_registry_url
}
