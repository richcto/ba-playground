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
| **Method** | `POST` |
| **URL** | `{{base_url}}/produce` |

Replace `{{base_url}}` with your Producer API URL, or set it as a Postman variable.

### 3. Set the request body

1. Go to the **Body** tab
2. Select **raw**
3. Choose **JSON** from the dropdown
4. Paste the following:

```json
{
  "topic": "ticket-purchases",
  "message": {
    "order_id": "ORD-001",
    "customer_id": "CUST-123",
    "event_id": "EVT-456",
    "quantity": 2,
    "purchased_at": "2026-02-28T12:00:00Z"
  }
}
```

### 4. Send the request

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
| 400 Missing topic | `topic` field missing in body | Add `"topic": "ticket-purchases"` to JSON body |
| 400 Missing message | `message` field missing in body | Add `"message": {...}` with valid TicketPurchase object |
| 400 Invalid JSON | Malformed JSON in body | Check quotes, commas, brackets |
| 500 | Schema validation failed or backend error | Ensure all required fields are present and types are correct |

## Tips

- **customer_id** is optional; omit it or use `null` if not needed
- **quantity** must be a number (e.g. `2`), not a string (`"2"`)
- **purchased_at** should be ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
- To send different messages, change only the `message` object in the JSON body
