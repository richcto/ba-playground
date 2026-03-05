variable "topic_name" {
  description = "Kafka topic name"
  type        = string
  default     = "ticket-purchases"
}

variable "partitions" {
  description = "Number of partitions for the topic"
  type        = number
  default     = 3
}

variable "replication_factor" {
  description = "Replication factor (use 1 for single-broker)"
  type        = number
  default     = 1
}

variable "retention_ms" {
  description = "Message retention in milliseconds (default 7 days)"
  type        = string
  default     = "604800000"
}
