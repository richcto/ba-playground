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
logger.setLevel(logging.DEBUG)
logging.getLogger().setLevel(logging.DEBUG)


def handler(event, context):
    """
    Lambda handler for Kafka consumer.

    Consumes from the topic specified in the event payload.
    Event format: {"topic": "topic-name"}
    """
    logger.debug("Consumer invoked, event: %s", event)

    topic = event.get("topic")
    if not topic:
        logger.warning("Missing topic in event payload")
        return {"statusCode": 400, "body": json.dumps({"error": "Missing topic in event payload"})}

    logger.debug("Consuming from topic: %s", topic)

    bootstrap_servers = os.environ.get("KAFKA_BOOTSTRAP_SERVERS")
    if not bootstrap_servers:
        logger.error("KAFKA_BOOTSTRAP_SERVERS not configured")
        return {"statusCode": 500, "body": json.dumps({"error": "Kafka not configured"})}
    logger.debug("Bootstrap servers: %s", bootstrap_servers)

    try:
        logger.debug("Creating KafkaConsumer...")
        consumer = KafkaConsumer(
            topic,
            bootstrap_servers=bootstrap_servers.split(","),
            value_deserializer=lambda v: v.decode("utf-8") if v else None,
            auto_offset_reset="earliest",
            consumer_timeout_ms=5000,
        )
        logger.debug("Consumer created, polling for messages (timeout 5s)...")

        messages = []
        for record in consumer:
            msg = {
                "partition": record.partition,
                "offset": record.offset,
                "value": record.value,
            }
            messages.append(msg)
            logger.info("Consumed record partition=%s offset=%s value=%s", record.partition, record.offset, record.value)

        consumer.close()
        logger.info("Consumed %d message(s) from topic=%s", len(messages), topic)
    except Exception as e:
        logger.exception("Failed to consume from Kafka: %s", e)
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}

    return {
        "statusCode": 200,
        "body": json.dumps({"topic": topic, "messages": messages}),
    }
