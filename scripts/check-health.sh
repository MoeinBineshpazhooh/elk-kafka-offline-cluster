#!/usr/bin/env bash
set -euo pipefail

ES_URL="${ES_URL:-https://10.10.4.101:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-}"
ES_CACERT="${ES_CACERT:-}"

KIBANA_URL="${KIBANA_URL:-http://10.10.4.111:5601}"
LOGSTASH_API="${LOGSTASH_API:-http://127.0.0.1:9600}"

echo "== Elasticsearch =="
if [[ -n "${ES_CACERT}" ]]; then
  curl -sS --cacert "${ES_CACERT}" -u "${ES_USER}:${ES_PASS}" "${ES_URL}/_cluster/health?pretty" | head -n 40
else
  curl -sS -k -u "${ES_USER}:${ES_PASS}" "${ES_URL}/_cluster/health?pretty" | head -n 40
fi

echo
echo "== Kibana =="
curl -sS "${KIBANA_URL}/api/status" | head -n 40 || true

echo
echo "== Logstash API =="
curl -sS "${LOGSTASH_API}/_node/pipelines?pretty" | head -n 40 || true

echo
echo "Done."
