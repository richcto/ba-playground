resource "kafka_topic" "topic" {
  name               = var.topic_name
  partitions         = var.partitions
  replication_factor = var.replication_factor

  config = {
    "retention.ms" = var.retention_ms
  }
}
