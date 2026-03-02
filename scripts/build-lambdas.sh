#!/bin/bash
# Build Lambda packages with dependencies. Run before terraform plan/apply.
set -e
cd "$(dirname "$0")/.."

for lambda in producer consumer; do
  mkdir -p build/$lambda
  cp lambdas/$lambda/*.py build/$lambda/ 2>/dev/null || true
  pip install -r lambdas/$lambda/requirements.txt -t build/$lambda/ -q
done

echo "Built build/producer and build/consumer"
