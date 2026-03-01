"""
Kafka Producer Lambda handler.

Accepts GET requests via API Gateway.
Query params: topic (required), message (required).
"""

import json
import logging
import os

from kafka import KafkaProducer

logger = logging.getLogger(__name__)


def handler(event, context):
    """
    Lambda handler for Kafka producer API.

    Handles GET requests. Event structure follows API Gateway HTTP API format.
    Query params: topic, message.
    """
    http_method = event.get("requestContext", {}).get("http", {}).get("method", "GET")

    if http_method == "GET":
        return handle_get(event)
    else:
        return response(405, {"error": f"Method {http_method} not allowed"})


def handle_get(event):
    """Handle GET requests - produce message to Kafka topic from query params."""
    query_params = event.get("queryStringParameters") or {}
    topic = query_params.get("topic")
    message = query_params.get("message")

    if not topic:
        return response(400, {"error": "Missing required query parameter: topic"})
    if message is None:
        return response(400, {"error": "Missing required query parameter: message"})

    bootstrap_servers = os.environ.get("KAFKA_BOOTSTRAP_SERVERS")
    if not bootstrap_servers:
        logger.error("KAFKA_BOOTSTRAP_SERVERS not configured")
        return response(500, {"error": "Kafka not configured"})

    try:
        producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers.split(","),
            value_serializer=lambda v: v.encode("utf-8"),
        )
        producer.send(topic, value=message)
        producer.flush()
        producer.close()
    except Exception as e:
        logger.exception("Failed to produce to Kafka: %s", e)
        return response(500, {"error": str(e)})

    return response(200, {
        "message": "Message produced",
        "topic": topic,
        "message": message,
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
