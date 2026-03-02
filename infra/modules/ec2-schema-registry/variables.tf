variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers (use private IP for same-VPC, e.g. 10.0.0.1:9092)"
  type        = string
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access Schema Registry on 8081"
  type        = list(string)
}
