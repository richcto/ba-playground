# Ticket Purchases Schema

## 1. Register schemas (run once)

Replace `SCHEMA_REGISTRY_URL` with your Schema Registry URL (e.g. `http://<schema-registry-ip>:8081`).

### Key schema (string)
```bash
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"schema": "{\"type\":\"string\"}"}' \
  "$SCHEMA_REGISTRY_URL/subjects/ticket-purchases-key/versions"
```

### Value schema (TicketPurchase record)
```bash
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"schema": "{\"type\":\"record\",\"name\":\"TicketPurchase\",\"namespace\":\"com.example.ticket\",\"fields\":[{\"name\":\"order_id\",\"type\":\"string\"},{\"name\":\"customer_id\",\"type\":[\"null\",\"string\"],\"default\":null},{\"name\":\"event_id\",\"type\":\"string\"},{\"name\":\"quantity\",\"type\":\"long\"},{\"name\":\"purchased_at\",\"type\":\"string\"}]}"}' \
  "$SCHEMA_REGISTRY_URL/subjects/ticket-purchases-value/versions"
```

Or use the script:
```bash
./scripts/register-schemas.sh http://<schema-registry-ip>:8081
```

## 2. Produce to topic (curl)

Replace `PRODUCER_API_URL` with `terraform output -raw producer_api_url` (e.g. `https://xxx.execute-api.eu-west-2.amazonaws.com/prod`).

```bash
# URL-encode the JSON message
curl -G "$PRODUCER_API_URL/produce" \
  --data-urlencode "topic=ticket-purchases" \
  --data-urlencode 'message={"order_id":"ORD-001","customer_id":"CUST-123","event_id":"EVT-456","quantity":2,"purchased_at":"2026-02-28T12:00:00Z"}'
```

Or with inline encoding:
```bash
curl "$PRODUCER_API_URL/produce?topic=ticket-purchases&message=%7B%22order_id%22%3A%22ORD-001%22%2C%22customer_id%22%3A%22CUST-123%22%2C%22event_id%22%3A%22EVT-456%22%2C%22quantity%22%3A2%2C%22purchased_at%22%3A%222026-02-28T12%3A00%3A00Z%22%7D"
```
