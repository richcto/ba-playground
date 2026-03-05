#!/bin/bash
# Register ticket-purchases schemas in Schema Registry.
# Usage: ./scripts/register-schemas.sh <SCHEMA_REGISTRY_URL>
# Example: ./scripts/register-schemas.sh http://1.2.3.4:8081

set -e
SCHEMA_REGISTRY_URL="${1:?Usage: $0 <SCHEMA_REGISTRY_URL>}"
SCHEMAS_DIR="$(dirname "$0")/../schemas"

register_schema() {
  local subject=$1
  local schema=$2
  local response
  local http_code

  echo -n "Registering $subject schema... "
  response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --connect-timeout 5 \
    --data "{\"schema\": $(echo "$schema" | jq -Rs .)}" \
    "$SCHEMA_REGISTRY_URL/subjects/$subject/versions" 2>/dev/null) || true
  http_code=$(echo "$response" | tail -n1)
  response=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "000" ]] || [[ -z "$http_code" ]]; then
    echo "FAILED"
    echo "  Error: Cannot connect to Schema Registry at $SCHEMA_REGISTRY_URL"
    exit 1
  fi
  if [[ "$http_code" != "200" ]]; then
    echo "FAILED (HTTP $http_code)"
    echo "$response" | jq . 2>/dev/null || echo "$response"
    exit 1
  fi
  echo "OK (id: $(echo "$response" | jq -r '.id'))"
}

# Register key schema
KEY_SCHEMA='{"type":"string"}'
register_schema "ticket-purchases-key" "$KEY_SCHEMA"

# Register value schema
if [[ ! -f "$SCHEMAS_DIR/ticket-purchases-value.avsc" ]]; then
  echo "Error: Schema file not found: $SCHEMAS_DIR/ticket-purchases-value.avsc"
  exit 1
fi
VALUE_SCHEMA=$(jq -c . "$SCHEMAS_DIR/ticket-purchases-value.avsc")
register_schema "ticket-purchases-value" "$VALUE_SCHEMA"

echo "Done."
