# User Guide – Submitting Messages with Postman

This guide explains how to submit ticket purchase messages to the Kafka topic using Postman.

## Prerequisites

- **Producer API URL** – Obtain from your administrator (e.g. `https://xxxxxx.execute-api.eu-west-2.amazonaws.com/prod`)
- Postman installed

## Message Format

Messages must be valid JSON matching the **TicketPurchase** schema:

| Field        | Type   | Required | Description                    |
|-------------|--------|----------|--------------------------------|
| order_id    | string | Yes      | Unique order identifier        |
| customer_id | string | No       | Customer identifier            |
| event_id    | string | Yes      | Event identifier               |
| quantity    | number | Yes      | Number of tickets               |
| purchased_at| string | Yes      | ISO 8601 timestamp (e.g. 2026-02-28T12:00:00Z) |

### Example message

```json
{
  "order_id": "ORD-001",
  "customer_id": "CUST-123",
  "event_id": "EVT-456",
  "quantity": 2,
  "purchased_at": "2026-02-28T12:00:00Z"
}
```

## Postman Setup

### 1. Create a new request

1. Open Postman
2. Click **New** → **HTTP Request**
3. Name it (e.g. "Submit Ticket Purchase")

### 2. Configure the request

| Setting | Value |
|---------|-------|
| **Method** | `GET` |
| **URL** | `{{base_url}}/produce` |

Replace `{{base_url}}` with your Producer API URL, or set it as a Postman variable.

### 3. Add query parameters

Go to the **Params** tab and add:

| Key     | Value |
|---------|-------|
| topic   | `ticket-purchases` |
| message | *(paste the JSON below)* |

**Message value** (copy exactly, no extra spaces):

```
{"order_id":"ORD-001","customer_id":"CUST-123","event_id":"EVT-456","quantity":2,"purchased_at":"2026-02-28T12:00:00Z"}
```

Postman will URL-encode the message automatically.

### 4. Full URL example

With params filled in, the URL will look like:

```
https://xxxxxx.execute-api.eu-west-2.amazonaws.com/prod/produce?topic=ticket-purchases&message=%7B%22order_id%22%3A%22ORD-001%22%2C%22customer_id%22%3A%22CUST-123%22%2C%22event_id%22%3A%22EVT-456%22%2C%22quantity%22%3A2%2C%22purchased_at%22%3A%222026-02-28T12%3A00%3A00Z%22%7D
```

### 5. Send the request

Click **Send**. A successful response (200) looks like:

```json
{
  "message": "Message produced",
  "topic": "ticket-purchases",
  "value": {
    "order_id": "ORD-001",
    "customer_id": "CUST-123",
    "event_id": "EVT-456",
    "quantity": 2,
    "purchased_at": "2026-02-28T12:00:00Z"
  }
}
```

## Postman Environment (optional)

1. Create an environment (e.g. "BA Kafka")
2. Add variable: `base_url` = `https://xxxxxx.execute-api.eu-west-2.amazonaws.com/prod`
3. Use `{{base_url}}/produce` as the request URL
4. Select the environment before sending

## Common Errors

| Response | Cause | Fix |
|----------|-------|-----|
| 400 Missing topic | `topic` param missing | Add `topic=ticket-purchases` |
| 400 Missing message | `message` param missing | Add `message` with valid JSON |
| 400 Invalid JSON | Malformed JSON in message | Check quotes, commas, brackets |
| 500 | Schema validation failed or backend error | Ensure all required fields are present and types are correct |

## Tips

- **customer_id** is optional; omit it or use `null` if not needed
- **quantity** must be a number (e.g. `2`), not a string (`"2"`)
- **purchased_at** should be ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
- To send different messages, change only the `message` param value
