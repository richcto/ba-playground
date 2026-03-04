"""
Kafka Producer Lambda handler.

Accepts POST requests via API Gateway.
Body (JSON): {"topic": "topic-name", "message": {...}}.
For ticket-purchases topic: message must be object matching TicketPurchase schema.
"""

import json
import logging
import os

from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import StringSerializer
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
with open(SCHEMA_PATH, encoding="utf-8") as _schema_file:
    VALUE_SCHEMA = _schema_file.read()


def handler(event, context):
    """Lambda handler for Kafka producer API."""
    logger.debug("Producer invoked, event keys: %s", list(event.keys()))
    http_method = event.get("requestContext", {}).get("http", {}).get("method", "POST")
    if http_method == "POST":
        return handle_post(event)
    return response(405, {"error": f"Method {http_method} not allowed"})


def handle_post(event):
    """Handle POST requests - produce message to Kafka topic from JSON body."""
    body = event.get("body")
    if not body:
        return response(400, {"error": "Missing request body"})
    try:
        data = json.loads(body)
    except json.JSONDecodeError as e:
        return response(400, {"error": f"Invalid JSON body: {e}"})

    topic = data.get("topic")
    message = data.get("message")

    if not topic:
        return response(400, {"error": "Missing required field: topic"})
    if message is None:
        return response(400, {"error": "Missing required field: message"})

    bootstrap_servers = os.environ.get("KAFKA_BOOTSTRAP_SERVERS")
    if not bootstrap_servers:
        return response(500, {"error": "Kafka not configured"})

    schema_registry_url = os.environ.get("SCHEMA_REGISTRY_URL")
    use_schema = schema_registry_url and topic == "ticket-purchases"

    if use_schema:
        if isinstance(message, dict):
            value_dict = message.copy()
        else:
            try:
                value_dict = json.loads(message) if isinstance(message, str) else message
            except (json.JSONDecodeError, TypeError):
                return response(400, {"error": "Message must be JSON object for ticket-purchases topic"})
        # Ensure types match schema
        if "quantity" in value_dict:
            value_dict["quantity"] = int(value_dict["quantity"])
    else:
        value_dict = message if isinstance(message, str) else json.dumps(message)

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
            producer.produce(topic=topic, value=value_dict)

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
