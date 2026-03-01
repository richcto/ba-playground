"""
Kafka Consumer Lambda handler.

Consumes messages from a Kafka topic specified in the event payload.
Uses DynamoDB for offset storage (avoids Kafka consumer group coordinator).
Event format: {"topic": "topic-name"}
"""

import json
import logging
import os

import boto3
from kafka import KafkaConsumer
from kafka.structs import TopicPartition

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
logging.getLogger().setLevel(logging.DEBUG)


def _get_offset(table, topic: str, partition: int) -> int | None:
    """Read stored offset from DynamoDB. Returns None if not found."""
    try:
        r = table.get_item(Key={"topic_partition": f"{topic}#{partition}"})
        item = r.get("Item")
        if item and "offset" in item:
            return int(item["offset"])
    except Exception as e:
        logger.warning("Failed to read offset for %s#%s: %s", topic, partition, e)
    return None


def _put_offset(table, topic: str, partition: int, offset: int) -> None:
    """Write offset to DynamoDB."""
    try:
        table.put_item(
            Item={
                "topic_partition": f"{topic}#{partition}",
                "offset": offset,
            }
        )
    except Exception as e:
        logger.warning("Failed to write offset for %s#%s: %s", topic, partition, e)


def handler(event, context):
    """
    Lambda handler for Kafka consumer.

    Consumes from the topic specified in the event payload.
    Uses DynamoDB for offsets instead of Kafka consumer groups.
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

    table_name = os.environ.get("OFFSETS_TABLE_NAME")
    if not table_name:
        logger.error("OFFSETS_TABLE_NAME not configured")
        return {"statusCode": 500, "body": json.dumps({"error": "Offsets table not configured"})}

    try:
        table = boto3.resource("dynamodb").Table(table_name)
        consumer = KafkaConsumer(
            bootstrap_servers=bootstrap_servers.split(","),
            value_deserializer=lambda v: v.decode("utf-8") if v else None,
            consumer_timeout_ms=2000,
        )

        # Get partitions for the topic and assign them (no consumer group)
        partitions = consumer.partitions_for_topic(topic)
        if not partitions:
            logger.warning("Topic %s has no partitions or does not exist", topic)
            consumer.close()
            return {"statusCode": 200, "body": json.dumps({"topic": topic, "messages": []})}

        tps = [TopicPartition(topic, p) for p in partitions]
        consumer.assign(tps)

        # Seek to stored offsets or beginning
        for tp in tps:
            stored = _get_offset(table, topic, tp.partition)
            if stored is not None:
                consumer.seek(tp, stored)
                logger.debug("Seeked %s to offset %s", tp, stored)
            else:
                consumer.seek_to_beginning(tp)
                logger.debug("Seeked %s to beginning", tp)

        logger.debug("Polling for messages (timeout 2s)...")
        messages = []
        for record in consumer:
            msg = {
                "partition": record.partition,
                "offset": record.offset,
                "value": record.value,
            }
            messages.append(msg)
            logger.info("Consumed record partition=%s offset=%s value=%s", record.partition, record.offset, record.value)

        # Persist offsets for all partitions we consumed from
        for tp in tps:
            pos = consumer.position(tp)
            _put_offset(table, topic, tp.partition, pos)

        consumer.close()
        logger.info("Consumed %d message(s) from topic=%s", len(messages), topic)
    except Exception as e:
        logger.exception("Failed to consume from Kafka: %s", e)
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}

    return {
        "statusCode": 200,
        "body": json.dumps({"topic": topic, "messages": messages}),
    }
