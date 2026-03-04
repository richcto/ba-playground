#!/bin/bash
# Build Lambda packages with dependencies. Run before terraform plan/apply.
set -e
cd "$(dirname "$0")/.."

for lambda in producer consumer; do
  mkdir -p infra/build/$lambda
  cp lambdas/$lambda/*.py infra/build/$lambda/ 2>/dev/null || true
  # Producer needs schemas for Avro serialization (single source of truth: schemas/*.avsc)
  [ "$lambda" = "producer" ] && mkdir -p infra/build/$lambda/schemas && cp schemas/*.avsc infra/build/$lambda/schemas/
  pip install -r lambdas/$lambda/requirements.txt -t infra/build/$lambda/ -q
done

echo "Built infra/build/producer and infra/build/consumer"
