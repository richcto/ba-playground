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
  default     = "t3.small"
}

variable "kafka_port" {
  description = "Kafka broker port"
  type        = number
  default     = 9092
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access Kafka and SSH (e.g. [\"109.151.168.190/32\"] for restricted, [\"0.0.0.0/0\"] for public)"
  type        = list(string)
}

variable "kafka_heap_opts" {
  description = "JVM heap options for Kafka (e.g. -Xms256m -Xmx384m for t3.micro)"
  type        = string
  default     = "-Xms256m -Xmx384m"
}

variable "kafka_docker_memory_mb" {
  description = "Docker container memory limit in MB"
  type        = number
  default     = 512
}

