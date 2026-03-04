"""
Kafka Consumer Lambda handler.

Consumes messages from a Kafka topic specified in the event payload.
Uses Kafka consumer groups for offset storage (conventional approach).
For ticket-purchases: deserializes Avro using Schema Registry.
Event format: {"topic": "topic-name"} or GET /consume/{topic}
"""

import json
import logging
import os
import time

from confluent_kafka.deserializing_consumer import DeserializingConsumer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroDeserializer

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
logging.getLogger().setLevel(logging.DEBUG)


def _deserialize_value(value):
    """Deserialize value - Avro dict or decode UTF-8."""
    if value is None:
        return None
    if isinstance(value, dict):
        return value
    if isinstance(value, bytes):
        return value.decode("utf-8")
    return value


def _http_response(status_code: int, body: dict) -> dict:
    """Build API Gateway HTTP API response."""
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    """Lambda handler for Kafka consumer. Supports direct invoke or API Gateway."""
    logger.debug("Consumer invoked, event: %s", event)

    # API Gateway: topic from path parameter GET /consume/{topic}
    path_params = event.get("pathParameters") or {}
    topic = path_params.get("topic") or event.get("topic")
    if not topic:
        return _http_response(400, {"error": "Missing topic. Use GET /consume/{topic} or pass topic in payload"})

    bootstrap_servers = os.environ.get("KAFKA_BOOTSTRAP_SERVERS")
    if not bootstrap_servers:
        return _http_response(500, {"error": "Kafka not configured"})

    schema_registry_url = os.environ.get("SCHEMA_REGISTRY_URL")
    use_schema = schema_registry_url and topic == "ticket-purchases"

    try:
        conf = {
            "bootstrap.servers": bootstrap_servers,
            "group.id": "lambda-consumer-api",
            "enable.auto.commit": False,
            "session.timeout.ms": 6000,
        }
        if use_schema:
            sr_client = SchemaRegistryClient({"url": schema_registry_url})
            conf["value.deserializer"] = AvroDeserializer(sr_client)
        else:
            conf["value.deserializer"] = lambda v, ctx: v.decode("utf-8") if v else None

        consumer = DeserializingConsumer(conf)

        metadata = consumer.list_topics(topic, timeout=10)
        if topic not in metadata.topics:
            logger.warning("Topic %s does not exist", topic)
            consumer.close()
            return _http_response(200, {"topic": topic, "messages": []})

        consumer.subscribe([topic])

        messages = []
        deadline = time.time() + 2.0
        while time.time() < deadline:
            msg = consumer.poll(timeout=1.0)
            if msg is None:
                continue
            if msg.error():
                if msg.error().code() == -191:  # PARTITION_EOF
                    continue
                logger.warning("Consumer error: %s", msg.error())
                continue
            value = _deserialize_value(msg.value())
            messages.append({
                "partition": msg.partition(),
                "offset": msg.offset(),
                "key": msg.key().decode("utf-8") if msg.key() else None,
                "value": value,
            })
            logger.info("Consumed partition=%s offset=%s value=%s", msg.partition(), msg.offset(), value)

        consumer.commit()
        consumer.close()
        logger.info("Consumed %d message(s) from topic=%s", len(messages), topic)
    except Exception as e:
        logger.exception("Failed to consume from Kafka: %s", e)
        return _http_response(500, {"error": str(e)})

    return _http_response(200, {"topic": topic, "messages": messages})
