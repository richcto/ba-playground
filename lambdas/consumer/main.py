"""
Kafka Consumer Lambda handler.

Consumes messages from a Kafka topic specified in the event payload.
Event format: {"topic": "topic-name"}
"""

import json
import logging
import os

from kafka import KafkaConsumer

logger = logging.getLogger(__name__)


def handler(event, context):
    """
    Lambda handler for Kafka consumer.

    Consumes from the topic specified in the event payload.
    Event format: {"topic": "topic-name"}
    """
    topic = event.get("topic")
    if not topic:
        return {"statusCode": 400, "body": json.dumps({"error": "Missing topic in event payload"})}

    bootstrap_servers = os.environ.get("KAFKA_BOOTSTRAP_SERVERS")
    if not bootstrap_servers:
        logger.error("KAFKA_BOOTSTRAP_SERVERS not configured")
        return {"statusCode": 500, "body": json.dumps({"error": "Kafka not configured"})}

    try:
        consumer = KafkaConsumer(
            topic,
            bootstrap_servers=bootstrap_servers.split(","),
            value_deserializer=lambda v: v.decode("utf-8") if v else None,
            auto_offset_reset="earliest",
            consumer_timeout_ms=5000,
        )

        messages = []
        for record in consumer:
            messages.append({
                "partition": record.partition,
                "offset": record.offset,
                "value": record.value,
            })
            logger.info("Consumed from %s: %s", topic, record.value)

        consumer.close()
    except Exception as e:
        logger.exception("Failed to consume from Kafka: %s", e)
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}

    return {
        "statusCode": 200,
        "body": json.dumps({"topic": topic, "messages": messages}),
    }
