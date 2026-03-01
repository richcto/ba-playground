"""
Kafka Consumer Lambda handler.

Consumes messages from Kafka topics via event source mapping.
Event format: https://docs.aws.amazon.com/lambda/latest/dg/with-kafka.html
"""

import base64
import json
import logging

logger = logging.getLogger(__name__)


def handler(event, context):
    """
    Lambda handler for Kafka consumer.

    Invoked by Kafka event source mapping. Event contains records from Kafka topics.
    """
    logger.info("Consumer received %d records", len(event.get("records", {})))

    for topic, records in event.get("records", {}).items():
        for record in records:
            try:
                process_record(topic, record)
            except Exception as e:
                logger.exception("Error processing record from %s: %s", topic, e)
                raise

    return {"statusCode": 200}


def process_record(topic: str, record: dict) -> None:
    """Process a single Kafka record."""
    # Decode value - may be base64 encoded
    value = record.get("value")
    if value:
        try:
            decoded = base64.b64decode(value).decode("utf-8")
            try:
                data = json.loads(decoded)
                logger.info("Topic %s: %s", topic, data)
            except json.JSONDecodeError:
                logger.info("Topic %s: %s", topic, decoded)
        except Exception:
            logger.info("Topic %s: (binary)", topic)
    else:
        logger.info("Topic %s: (empty)", topic)
