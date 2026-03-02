resource "kafka_topic" "ticket_purchases" {
  name               = "ticket-purchases"
  partitions         = 3
  replication_factor = 1

  config = {
    "retention.ms" = "604800000" # 7 days
  }
}
