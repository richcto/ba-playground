"""
Kafka Consumer Lambda handler.

Consumes messages from a Kafka topic specified in the event payload.
Uses Kafka consumer groups for offset storage (conventional approach).
For ticket-purchases: deserializes Avro using Schema Registry.
Event format: {"topic": "topic-name"} or GET /consume/{topic}
"""

# Standard library: JSON for request/response bodies
import json

# Standard library: logging for debug/info/warning messages
import logging

# Standard library: read environment variables (KAFKA_BOOTSTRAP_SERVERS, etc.)
import os

# Standard library: time.time() for poll deadline
import time

# Confluent Kafka: consumer that deserializes values (Avro or string)
from confluent_kafka.deserializing_consumer import DeserializingConsumer

# Confluent Kafka: client to fetch Avro schemas from Schema Registry
from confluent_kafka.schema_registry import SchemaRegistryClient

# Confluent Kafka: deserializer that converts Avro bytes to Python dict
from confluent_kafka.schema_registry.avro import AvroDeserializer

# Create logger named after this module (lambdas.consumer.main)
logger = logging.getLogger(__name__)
# Set this module's logger to DEBUG level (shows all messages)
logger.setLevel(logging.DEBUG)
# Set root logger to DEBUG so our messages are not filtered
logging.getLogger().setLevel(logging.DEBUG)


def _deserialize_value(value):
    """
    Normalize the consumed value for the API response.
    AvroDeserializer returns dict; string topics return bytes.
    """
    # None means tombstone or empty message
    if value is None:
        return None
    # Avro-deserialized messages are already Python dicts
    if isinstance(value, dict):
        return value
    # Plain string topics: decode bytes to UTF-8 string
    if isinstance(value, bytes):
        return value.decode("utf-8")
    # Fallback: return as-is (e.g. already a string)
    return value


def _http_response(status_code: int, body: dict) -> dict:
    """
    Build API Gateway HTTP API v2 response format.
    body is a dict; we JSON-serialize it for the response body.
    """
    return {
        # HTTP status code (200, 400, 500)
        "statusCode": status_code,
        # Required for JSON responses
        "headers": {"Content-Type": "application/json"},
        # API Gateway expects body as a string
        "body": json.dumps(body),
    }


def handler(event, context):
    """
    Lambda entry point. Invoked by API Gateway (GET /consume/{topic})
    or by direct invoke with {"topic": "topic-name"}.
    """
    # Log the raw event for debugging (includes pathParameters, body, etc.)
    logger.debug("Consumer invoked, event: %s", event)

    # API Gateway puts path params in pathParameters; direct invoke uses event.topic
    path_params = event.get("pathParameters") or {}
    topic = path_params.get("topic") or event.get("topic")
    # Reject if no topic provided
    if not topic:
        return _http_response(400, {"error": "Missing topic. Use GET /consume/{topic} or pass topic in payload"})

    # Kafka broker address (e.g. 172.31.x.x:9092) from Lambda environment
    bootstrap_servers = os.environ.get("KAFKA_BOOTSTRAP_SERVERS")
    if not bootstrap_servers:
        return _http_response(500, {"error": "Kafka not configured"})

    # Schema Registry URL for Avro; only ticket-purchases uses Avro
    schema_registry_url = os.environ.get("SCHEMA_REGISTRY_URL")
    use_schema = schema_registry_url and topic == "ticket-purchases"

    try:
        # Consumer config: connect to Kafka, use consumer group for offsets
        conf = {
            # Comma-separated broker list
            "bootstrap.servers": bootstrap_servers,
            # Consumer group ID; Kafka stores offsets per group
            "group.id": "lambda-consumer-api",
            # We commit manually after each poll batch
            "enable.auto.commit": False,
            # Max time before broker considers consumer dead (ms)
            "session.timeout.ms": 6000,
            # When no offset exists: start from beginning (not end)
            "auto.offset.reset": "earliest",
        }
        # Add value deserializer: Avro for ticket-purchases, UTF-8 for others
        if use_schema:
            # Client to fetch schemas from Schema Registry
            sr_client = SchemaRegistryClient({"url": schema_registry_url})
            # Deserializer fetches schema by ID from message, decodes Avro to dict
            conf["value.deserializer"] = AvroDeserializer(sr_client)
        else:
            # Simple UTF-8 decode for non-Avro topics
            conf["value.deserializer"] = lambda v, ctx: v.decode("utf-8") if v else None

        # Create consumer with the config
        consumer = DeserializingConsumer(conf)

        # Check topic exists before subscribing (avoids obscure errors)
        metadata = consumer.list_topics(topic, timeout=10)
        if topic not in metadata.topics:
            logger.warning("Topic %s does not exist", topic)
            consumer.close()
            return _http_response(200, {"topic": topic, "messages": []})

        # Subscribe to topic; Kafka assigns partitions and provides committed offsets
        consumer.subscribe([topic])

        # Collect messages until deadline
        messages = []
        # 8 seconds: enough for group join, partition assignment, and polling
        deadline = time.time() + 8.0
        while time.time() < deadline:
            # Poll for up to 1 second; returns Message or None if timeout
            msg = consumer.poll(timeout=1.0)
            # No message in this poll cycle
            if msg is None:
                continue
            # Check for Kafka errors (e.g. partition EOF, rebalance)
            if msg.error():
                # -191 = PARTITION_EOF: reached end of partition, not an error
                if msg.error().code() == -191:
                    continue
                logger.warning("Consumer error: %s", msg.error())
                continue
            # Deserialize value (Avro dict or UTF-8 string)
            value = _deserialize_value(msg.value())
            # Append to result with partition, offset, key for API response
            messages.append({
                "partition": msg.partition(),
                "offset": msg.offset(),
                "key": msg.key().decode("utf-8") if msg.key() else None,
                "value": value,
            })
            logger.info("Consumed partition=%s offset=%s value=%s", msg.partition(), msg.offset(), value)

        # Commit offsets so next invocation continues from here
        consumer.commit()
        # Release consumer resources and leave group
        consumer.close()
        logger.info("Consumed %d message(s) from topic=%s", len(messages), topic)
    except Exception as e:
        # Log full traceback and return 500
        logger.exception("Failed to consume from Kafka: %s", e)
        return _http_response(500, {"error": str(e)})

    # Return success with topic and messages
    return _http_response(200, {"topic": topic, "messages": messages})
