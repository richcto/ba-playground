"""
Kafka Submit Lambda handler.

Accepts GET and POST requests via API Gateway.
"""

import json


def handler(event, context):
    """
    Lambda handler for Kafka submit API.

    Handles GET and POST requests. Event structure follows API Gateway HTTP API format.
    """
    http_method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    path = event.get("requestContext", {}).get("http", {}).get("path", "/")

    if http_method == "GET":
        return handle_get(event)
    elif http_method == "POST":
        return handle_post(event)
    else:
        return response(405, {"error": f"Method {http_method} not allowed"})


def handle_get(event):
    """Handle GET requests."""
    query_params = event.get("queryStringParameters") or {}
    return response(200, {
        "message": "Kafka submit API",
        "method": "GET",
        "query_params": query_params,
    })


def handle_post(event):
    """Handle POST requests."""
    body = event.get("body") or "{}"
    try:
        parsed = json.loads(body) if body else {}
    except json.JSONDecodeError:
        parsed = {"raw": body}

    # TODO: Add Kafka submission logic here
    return response(200, {
        "message": "Kafka submit API",
        "method": "POST",
        "received": parsed,
    })


def response(status_code: int, body: dict) -> dict:
    """Build API Gateway HTTP API response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps(body),
    }
