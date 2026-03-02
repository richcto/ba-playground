"""
Kafka Producer Lambda handler.

Accepts GET requests via API Gateway.
Query params: topic (required), message (required).
"""

import json
import logging
import os
from urllib.parse import parse_qs

from kafka import KafkaProducer

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
logging.getLogger().setLevel(logging.DEBUG)


def _get_query_params(event):
    """Extract query params from API Gateway event. Handles both queryStringParameters and rawQueryString."""
    params = event.get("queryStringParameters")
    if params is not None:
        return dict(params)

    raw = event.get("rawQueryString")
    if raw:
        parsed = parse_qs(raw, keep_blank_values=True)
        return {k: v[0] if len(v) == 1 else v for k, v in parsed.items()}

    return {}


def handler(event, context):
    """
    Lambda handler for Kafka producer API.

    Handles GET requests. Event structure follows API Gateway HTTP API format.
    Query params: topic, message.
    """
    logger.debug("Producer invoked, event keys: %s", list(event.keys()))
    http_method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    logger.debug("HTTP method: %s", http_method)

    if http_method == "GET":
        return handle_get(event)
    else:
        return response(405, {"error": f"Method {http_method} not allowed"})


def handle_get(event):
    """Handle GET requests - produce message to Kafka topic from query params."""
    query_params = _get_query_params(event)
    logger.debug("Query params: %s (rawQueryString: %s)", query_params, event.get("rawQueryString"))

    topic = query_params.get("topic")
    message = query_params.get("message")

    if not topic:
        logger.warning("Missing topic in query params")
        return response(400, {"error": "Missing required query parameter: topic"})
    if message is None:
        logger.warning("Missing message in query params")
        return response(400, {"error": "Missing required query parameter: message"})

    logger.debug("Producing to topic=%s message=%s", topic, message)

    bootstrap_servers = os.environ.get("KAFKA_BOOTSTRAP_SERVERS")
    if not bootstrap_servers:
        logger.error("KAFKA_BOOTSTRAP_SERVERS not configured")
        return response(500, {"error": "Kafka not configured"})
    logger.debug("Bootstrap servers: %s", bootstrap_servers)

    try:
        logger.debug("Creating KafkaProducer...")
        producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers.split(","),
            value_serializer=lambda v: v.encode("utf-8"),
        )
        logger.debug("Producer created, sending message...")
        producer.send(topic, value=message)
        logger.debug("Flushing producer...")
        producer.flush()
        producer.close()
        logger.info("Successfully produced message to topic=%s", topic)
    except Exception as e:
        logger.exception("Failed to produce to Kafka: %s", e)
        return response(500, {"error": str(e)})

    return response(200, {
        "message": "Message produced",
        "topic": topic,
        "value": message,
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
