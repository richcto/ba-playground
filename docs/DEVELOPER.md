# Developer Documentation

## Overview

This project provides a Kafka-based messaging system with:

- **EC2 Kafka** – Single-node Apache Kafka (KRaft) with dual listeners (internal/external)
- **Schema Registry** – Confluent Schema Registry for Avro schema enforcement
- **Producer Lambda** – API Gateway HTTP API that produces messages to Kafka
- **Consumer Lambda** – Consumes from Kafka topics, uses consumer groups for offset storage
- **Terraform** – Infrastructure as code split into `infra/` and `kafka/` directories

## Project Structure

```
BA/
├── infra/                 # AWS infrastructure (EC2, Lambdas)
│   ├── main.tf
│   ├── modules/
│   │   ├── ec2-kafka/
│   │   ├── ec2-schema-registry/
│   │   └── lambda/
│   └── build/             # Lambda packages (generated, not committed)
├── kafka/                 # Kafka topic management (separate state)
├── lambdas/
│   ├── producer/          # Producer Lambda code
│   └── consumer/          # Consumer Lambda code
├── schemas/               # Avro schemas for ticket-purchases
├── scripts/               # Schema registration, listing
└── .github/workflows/     # deploy-infra.yml, deploy-kafka.yml
```

## Prerequisites

- Terraform >= 1.0
- Python 3.12
- AWS CLI (for local runs)
- jq (for schema scripts)

## Local Development

### Build Lambda packages

```bash
for lambda in producer consumer; do
  mkdir -p infra/build/$lambda
  cp lambdas/$lambda/*.py infra/build/$lambda/ 2>/dev/null || true
  [ "$lambda" = "producer" ] && mkdir -p infra/build/$lambda/schemas && cp schemas/*.avsc infra/build/$lambda/schemas/
  pip install -r lambdas/$lambda/requirements.txt -t infra/build/$lambda/ --quiet
done
```

### Terraform

```bash
cd infra
terraform init
terraform plan
terraform apply
```

### Register schemas (after infra is deployed)

```bash
SCHEMA_REGISTRY_URL=$(terraform -chdir=infra output -raw schema_registry_url)
./scripts/register-schemas.sh "$SCHEMA_REGISTRY_URL"
```

### Kafka topics (separate workflow)

Run the `deploy-kafka` workflow (workflow_dispatch) after EC2 Kafka is up. Parameters:

| Parameter   | Default          | Description           |
|-------------|------------------|-----------------------|
| topic_name  | ticket-purchases | Topic name            |
| partitions  | 3                | Number of partitions  |

Each topic uses its own Terraform state file (`kafka/{topic_name}.tfstate`). Other settings (replication_factor=1, retention=7 days) use defaults; override via `-var` if needed.

## Schemas

- **ticket-purchases-key**: string (order_id)
- **ticket-purchases-value**: `TicketPurchase` record with `order_id`, `customer_id`, `event_id`, `quantity`, `purchased_at`

See `schemas/README.md` for schema details and registration commands.

## Workflows

| Workflow       | Trigger              | Purpose                          |
|----------------|----------------------|----------------------------------|
| deploy-infra   | PR, workflow_dispatch | Plan/apply/destroy AWS infra   |
| deploy-kafka   | workflow_dispatch    | Create Kafka topics (topic_name, partitions params) |

### Kafka ingress mode

- **restricted** (default): Only your IP can access Kafka and Schema Registry (ports 9092, 9094, 8081)
- **public**: Open to 0.0.0.0/0 (for GitHub Actions, Lambdas)

Set `kafka_ingress_mode=public` in workflow_dispatch when running the Kafka pipeline.

### Kafka memory tuning

Defaults target **t3.micro** (1GB): heap 256MB, container 384MB. If Kafka becomes unresponsive:

```bash
# t3.micro (1GB) - defaults
terraform apply

# t3.small (2GB) - more headroom
terraform apply -var="kafka_heap_opts=-Xms512m -Xmx1g" -var="kafka_docker_memory_mb=1024" -var="ec2_instance_type=t3.small"
```

### CloudWatch memory metrics

CloudWatch agent runs on both Kafka and Schema Registry EC2 instances. Metrics are in:
- **BA/Kafka** – Kafka instance (mem_used_percent, mem_available, mem_used, disk_used_percent)
- **BA/SchemaRegistry** – Schema Registry instance

In CloudWatch → Metrics → Custom namespaces → BA/Kafka or BA/SchemaRegistry.

## Key Outputs

```bash
terraform -chdir=infra output
# producer_api_url      – Producer API (POST /produce)
# consumer_api_url      – Consumer API (GET /consume/{topic})
# schema_registry_url   – Schema Registry URL
# kafka_bootstrap_servers – Kafka EXTERNAL listener (public_ip:9094)
```

## Migration

See `MIGRATION.md` for state migration when moving between root and infra/kafka layout.
