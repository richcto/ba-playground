"""
Kafka Producer Lambda handler.

Accepts GET requests via API Gateway.
Query params: topic (required), message (required).
For ticket-purchases topic: message must be JSON matching TicketPurchase schema.
"""

import json
import logging
import os
from urllib.parse import parse_qs

from confluent_kafka.serialization import StringSerializer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serializing_producer import SerializingProducer

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
logging.getLogger().setLevel(logging.DEBUG)

# TicketPurchase Avro schema - load canonical schema from .avsc file
SCHEMA_PATH = os.path.join(
    os.path.dirname(__file__),
    "..",
    "..",
    "schemas",
    "ticket-purchases-value.avsc",
)
with open(SCHEMA_PATH, "r", encoding="utf-8") as _schema_file:
    VALUE_SCHEMA = _schema_file.read()


def _get_query_params(event):
    """Extract query params from API Gateway event."""
    params = event.get("queryStringParameters")
    if params is not None:
        return dict(params)
    raw = event.get("rawQueryString")
    if raw:
        parsed = parse_qs(raw, keep_blank_values=True)
        return {k: v[0] if len(v) == 1 else v for k, v in parsed.items()}
    return {}


def handler(event, context):
    """Lambda handler for Kafka producer API."""
    logger.debug("Producer invoked, event keys: %s", list(event.keys()))
    http_method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    if http_method == "GET":
        return handle_get(event)
    return response(405, {"error": f"Method {http_method} not allowed"})


def handle_get(event):
    """Handle GET requests - produce message to Kafka topic from query params."""
    query_params = _get_query_params(event)
    topic = query_params.get("topic")
    message = query_params.get("message")

    if not topic:
        return response(400, {"error": "Missing required query parameter: topic"})
    if message is None:
        return response(400, {"error": "Missing required query parameter: message"})

    bootstrap_servers = os.environ.get("KAFKA_BOOTSTRAP_SERVERS")
    if not bootstrap_servers:
        return response(500, {"error": "Kafka not configured"})

    schema_registry_url = os.environ.get("SCHEMA_REGISTRY_URL")
    use_schema = schema_registry_url and topic == "ticket-purchases"

    if use_schema:
        try:
            value_dict = json.loads(message)
            # Ensure types match schema
            if "quantity" in value_dict:
                value_dict["quantity"] = int(value_dict["quantity"])
        except json.JSONDecodeError as e:
            return response(400, {"error": f"Invalid JSON message: {e}"})
    else:
        value_dict = message

    try:
        if use_schema:
            sr_client = SchemaRegistryClient({"url": schema_registry_url})
            value_serializer = AvroSerializer(sr_client, VALUE_SCHEMA)
            producer = SerializingProducer({
                "bootstrap.servers": bootstrap_servers,
                "key.serializer": StringSerializer("utf-8"),
                "value.serializer": value_serializer,
            })
            producer.produce(topic=topic, value=value_dict, key=value_dict.get("order_id", ""))
        else:
            def _str_serializer(obj, ctx):
                return (obj if isinstance(obj, bytes) else str(obj).encode("utf-8"))
            producer = SerializingProducer({
                "bootstrap.servers": bootstrap_servers,
                "value.serializer": _str_serializer,
            })
            producer.produce(topic=topic, value=message)

        producer.flush()
        logger.info("Successfully produced message to topic=%s", topic)
    except Exception as e:
        logger.exception("Failed to produce to Kafka: %s", e)
        return response(500, {"error": str(e)})

    return response(200, {
        "message": "Message produced",
        "topic": topic,
        "value": value_dict if use_schema else message,
    })


def response(status_code: int, body: dict) -> dict:
    """Build API Gateway HTTP API response."""
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
