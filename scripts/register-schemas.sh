#!/bin/bash
# Register ticket-purchases schemas in Schema Registry.
# Usage: ./scripts/register-schemas.sh <SCHEMA_REGISTRY_URL>
# Example: ./scripts/register-schemas.sh http://1.2.3.4:8081

set -e
SCHEMA_REGISTRY_URL="${1:?Usage: $0 <SCHEMA_REGISTRY_URL>}"
SCHEMAS_DIR="$(dirname "$0")/../schemas"

# Register key schema (compact JSON string)
KEY_SCHEMA='{"type":"string"}'
echo "Registering ticket-purchases-key schema..."
curl -s -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data "{\"schema\": $(echo "$KEY_SCHEMA" | jq -Rs .)}" \
  "$SCHEMA_REGISTRY_URL/subjects/ticket-purchases-key/versions" | jq .

# Register value schema (read from file, compact, escape)
VALUE_SCHEMA=$(jq -c . "$SCHEMAS_DIR/ticket-purchases-value.avsc")
echo "Registering ticket-purchases-value schema..."
curl -s -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data "{\"schema\": $(echo "$VALUE_SCHEMA" | jq -Rs .)}" \
  "$SCHEMA_REGISTRY_URL/subjects/ticket-purchases-value/versions" | jq .

echo "Done."
