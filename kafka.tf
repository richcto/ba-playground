# Kafka topic - requires kafka_bootstrap_servers variable
# After first apply: terraform apply -var="kafka_bootstrap_servers=$(terraform output -raw kafka_bootstrap_servers)"
resource "kafka_topic" "ticket_purchases" {
  count = length(var.kafka_bootstrap_servers) > 0 ? 1 : 0

  name               = "ticket-purchases"
  partitions         = 3
  replication_factor = 1

  config = {
    "retention.ms" = "604800000" # 7 days
  }
}
