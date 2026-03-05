#!/bin/bash
# List schemas registered in Schema Registry.
# Usage: ./scripts/list-schemas.sh <SCHEMA_REGISTRY_URL> [--verbose]
# Example: ./scripts/list-schemas.sh http://1.2.3.4:8081
#          ./scripts/list-schemas.sh http://1.2.3.4:8081 --verbose

set -e
SCHEMA_REGISTRY_URL="${1:?Usage: $0 <SCHEMA_REGISTRY_URL>}"
VERBOSE=false
[[ "${2:-}" == "--verbose" ]] && VERBOSE=true

echo "Schema Registry: $SCHEMA_REGISTRY_URL"
echo "---"

SUBJECTS=$(curl -s -w "\n%{http_code}" -H "Accept: application/vnd.schemaregistry.v1+json" \
  --connect-timeout 5 \
  "$SCHEMA_REGISTRY_URL/subjects" 2>/dev/null) || true
HTTP_CODE=$(echo "$SUBJECTS" | tail -n1)
SUBJECTS=$(echo "$SUBJECTS" | sed '$d')

if [[ "$HTTP_CODE" != "200" ]]; then
  if [[ "$HTTP_CODE" == "000" ]] || [[ -z "$HTTP_CODE" ]]; then
    echo "Error: Cannot connect to Schema Registry at $SCHEMA_REGISTRY_URL"
    echo "       (Connection refused, timeout, or host unreachable. Check firewall/security group and kafka_ingress_mode.)"
  else
    echo "Error: Schema Registry returned HTTP $HTTP_CODE"
    echo "$SUBJECTS" | jq . 2>/dev/null || echo "$SUBJECTS"
  fi
  exit 1
fi

if [[ "$SUBJECTS" == "[]" ]] || [[ -z "$SUBJECTS" ]]; then
  echo "No subjects registered."
  exit 0
fi

for subject in $(echo "$SUBJECTS" | jq -r '.[]'); do
  VERSIONS=$(curl -s -H "Accept: application/vnd.schemaregistry.v1+json" \
    "$SCHEMA_REGISTRY_URL/subjects/$subject/versions")
  COUNT=$(echo "$VERSIONS" | jq 'length')
  echo "$subject ($COUNT version(s))"

  if [[ "$VERBOSE" == "true" ]]; then
    LATEST=$(curl -s -H "Accept: application/vnd.schemaregistry.v1+json" \
      "$SCHEMA_REGISTRY_URL/subjects/$subject/versions/latest")
    SCHEMA=$(echo "$LATEST" | jq -r '.schema // empty')
    if [[ -n "$SCHEMA" ]]; then
      echo "$SCHEMA" | jq . 2>/dev/null || echo "$SCHEMA"
    fi
    echo ""
  fi
done
