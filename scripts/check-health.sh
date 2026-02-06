#!/usr/bin/env bash
set -euo pipefail

# Health checks for ELK + Kafka cluster.
# Intended to be run from an operator machine that can reach services over the network.

# --- Config (override via env vars) ---
ES_URL="${ES_URL:-https://10.10.4.101:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-${ELASTIC_PASSWORD:-}}"

KIBANA_URL="${KIBANA_URL:-https://10.10.4.111:5601}"
LOGSTASH_URL="${LOGSTASH_URL:-http://10.10.4.111:9600}"

# Path to CA cert on operator host (optional). If empty, -k is used.
CA_CERT="${CA_CERT:-}"

# Kafka checks (optional): run these on a host that has kafka container
KAFKA_BROKER_CONTAINER="${KAFKA_BROKER_CONTAINER:-kafka-broker01}"
KAFKA_BOOTSTRAP="${KAFKA_BOOTSTRAP:-10.10.4.131:9092}"

# --- Helpers ---
curl_es() {
  if [[ -n "${CA_CERT}" && -f "${CA_CERT}" ]]; then
    curl --silent --show-error --fail --cacert "${CA_CERT}" -u "${ES_USER}:${ES_PASS}" "$@"
  else
    curl --silent --show-error --fail -k -u "${ES_USER}:${ES_PASS}" "$@"
  fi
}

curl_kibana() {
  if [[ -n "${CA_CERT}" && -f "${CA_CERT}" ]]; then
    curl --silent --show-error --fail --cacert "${CA_CERT}" "$@"
  else
    curl --silent --show-error --fail -k "$@"
  fi
}

ok() { echo "✓ $*"; }
warn() { echo "! $*" >&2; }
fail() { echo "✗ $*" >&2; exit 1; }

# --- Elasticsearch ---
if [[ -z "${ES_PASS}" ]]; then
  warn "ELASTIC_PASSWORD/ES_PASS is empty. ES checks may fail if auth is enabled."
fi

echo "[CHECK] Elasticsearch cluster health: ${ES_URL}"
ES_HEALTH="$(curl_es "${ES_URL}/_cluster/health" || true)"
if echo "${ES_HEALTH}" | grep -q '"status":"green"'; then
  ok "Elasticsearch cluster health: GREEN"
elif echo "${ES_HEALTH}" | grep -q '"status":"yellow"'; then
  ok "Elasticsearch cluster health: YELLOW"
else
  echo "${ES_HEALTH}" | head -c 400 || true
  fail "Elasticsearch health check failed"
fi

echo "[CHECK] Elasticsearch nodes"
ES_NODES="$(curl_es "${ES_URL}/_cat/nodes?v" || true)"
if [[ -n "${ES_NODES}" ]]; then
  ok "Elasticsearch nodes endpoint reachable"
else
  fail "Elasticsearch nodes check failed"
fi

# --- Kibana ---
echo "[CHECK] Kibana status: ${KIBANA_URL}/api/status"
KIBANA_STATUS="$(curl_kibana "${KIBANA_URL}/api/status" || true)"
if echo "${KIBANA_STATUS}" | grep -qi '"level":"available"\|"overall"'; then
  ok "Kibana: RUNNING"
else
  echo "${KIBANA_STATUS}" | head -c 400 || true
  warn "Kibana status endpoint returned unexpected output (may still be starting)"
fi

# --- Logstash ---
echo "[CHECK] Logstash API: ${LOGSTASH_URL}/_node/pipelines"
LOGSTASH_STATUS="$(curl --silent --show-error --fail "${LOGSTASH_URL}/_node/pipelines" 2>/dev/null || true)"
if [[ -n "${LOGSTASH_STATUS}" ]]; then
  ok "Logstash: RUNNING"
else
  warn "Logstash API not reachable (is Logstash running on ${LOGSTASH_URL}?)"
fi

# --- Kafka (optional) ---
echo "[CHECK] Kafka brokers (optional)"
if docker ps --format '{{.Names}}' | grep -q "^${KAFKA_BROKER_CONTAINER}$"; then
  if docker exec "${KAFKA_BROKER_CONTAINER}" bash -lc "kafka-broker-api-versions.sh --bootstrap-server ${KAFKA_BOOTSTRAP} >/dev/null 2>&1"; then
    ok "Kafka brokers: reachable via ${KAFKA_BOOTSTRAP}"
  else
    warn "Kafka check failed inside container ${KAFKA_BROKER_CONTAINER}"
  fi
else
  warn "Kafka broker container '${KAFKA_BROKER_CONTAINER}' not found on this host. Skipping Kafka check."
fi

echo ""
echo "Health checks completed."
