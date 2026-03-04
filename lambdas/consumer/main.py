"""
Kafka Consumer Lambda handler.

Consumes messages from a Kafka topic specified in the event payload.
Uses DynamoDB for offset storage (avoids Kafka consumer group coordinator).
For ticket-purchases: deserializes Avro using Schema Registry.
Event format: {"topic": "topic-name"}
"""

import json
import logging
import os

import boto3
from confluent_kafka import TopicPartition
from confluent_kafka.deserializing_consumer import DeserializingConsumer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroDeserializer

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

    table_name = os.environ.get("OFFSETS_TABLE_NAME")
    if not table_name:
        return _http_response(500, {"error": "Offsets table not configured"})

    schema_registry_url = os.environ.get("SCHEMA_REGISTRY_URL")
    use_schema = schema_registry_url and topic == "ticket-purchases"

    try:
        table = boto3.resource("dynamodb").Table(table_name)

        conf = {
            "bootstrap.servers": bootstrap_servers,
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

        partition_ids = list(metadata.topics[topic].partitions.keys())
        partitions = [TopicPartition(topic, p) for p in partition_ids]
        consumer.assign(partitions)

        for tp in partitions:
            stored = _get_offset(table, topic, tp.partition)
            if stored is not None:
                consumer.seek(tp, stored)
            else:
                consumer.seek(tp, 0)

        messages = []
        deadline = __import__("time").time() + 2.0
        while __import__("time").time() < deadline:
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

        for tp in partitions:
            tps = consumer.position([tp])
            if tps:
                _put_offset(table, topic, tp.partition, tps[0].offset)

        consumer.close()
        logger.info("Consumed %d message(s) from topic=%s", len(messages), topic)
    except Exception as e:
        logger.exception("Failed to consume from Kafka: %s", e)
        return _http_response(500, {"error": str(e)})

    return _http_response(200, {"topic": topic, "messages": messages})
