#!/usr/bin/env bash
set -euo pipefail

# Portfolio-safe example. Replace placeholders locally.
ELASTICSEARCH_URL="${ELASTICSEARCH_URL:-https://<ELASTICSEARCH_HOST>:9200}"
CA_CERT="${CA_CERT:-/path/to/ca.crt}"
ELASTIC_USER="${ELASTIC_USER:-elastic}"
ELASTIC_PASSWORD="${ELASTIC_PASSWORD:-CHANGE_ME_ELASTIC_PASSWORD}"
INDEX_NAME="${INDEX_NAME:-demo-logs-000001}"
ROLLOVER_ALIAS="${ROLLOVER_ALIAS:-demo-logs}"

curl --fail --silent --show-error \
  --cacert "$CA_CERT" \
  -u "${ELASTIC_USER}:${ELASTIC_PASSWORD}" \
  -X PUT \
  "${ELASTICSEARCH_URL}/${INDEX_NAME}" \
  -H 'Content-Type: application/json' \
  --data-binary @- <<EOF
{
  "aliases": {
    "${ROLLOVER_ALIAS}": {
      "is_write_index": true
    }
  }
}
EOF

echo "Created ${INDEX_NAME} with write alias ${ROLLOVER_ALIAS}."
