#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_SERVERS="${BOOTSTRAP_SERVERS:-192.0.2.21:9092,192.0.2.22:9092,192.0.2.23:9092}"
CONFIG_FILE="${CONFIG_FILE:-./admin-client.properties}"
KAFKA_CONTAINER="${KAFKA_CONTAINER:-kafka-broker01}"
CONTAINER_CONFIG="/tmp/kafka-admin-client.properties"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "[ERROR] Admin client configuration not found: ${CONFIG_FILE}"
  echo "Create it locally from admin-client.properties.example; never commit the real file."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] docker command not found"
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${KAFKA_CONTAINER}$"; then
  echo "[ERROR] Kafka container '${KAFKA_CONTAINER}' not found."
  echo "Set KAFKA_CONTAINER to the broker container name on this host."
  exit 1
fi

# The admin properties file is copied only to the running container and removed on exit.
docker cp "${CONFIG_FILE}" "${KAFKA_CONTAINER}:${CONTAINER_CONFIG}"
cleanup() {
  docker exec "${KAFKA_CONTAINER}" rm -f "${CONTAINER_CONFIG}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

run_acl() {
  docker exec "${KAFKA_CONTAINER}" bash -lc \
    "/opt/kafka/bin/kafka-acls.sh --bootstrap-server '${BOOTSTRAP_SERVERS}' --command-config '${CONTAINER_CONFIG}' $*"
}

echo "[INFO] Applying sanitized least-privilege ACLs..."

run_acl --add --allow-principal User:filebeat --operation WRITE --operation DESCRIBE --topic demo-application-logs
run_acl --add --allow-principal User:logstash --operation READ --operation DESCRIBE --topic demo-application-logs
run_acl --add --allow-principal User:collector --operation WRITE --operation DESCRIBE --topic demo-platform-events
run_acl --add --allow-principal User:akhq --operation READ --operation DESCRIBE --topic demo-application-logs
run_acl --add --allow-principal User:akhq --operation READ --operation DESCRIBE --topic demo-platform-events
run_acl --add --allow-principal User:akhq --operation DESCRIBE --cluster
run_acl --add --allow-principal User:app --operation WRITE --operation DESCRIBE --topic demo-application-logs

# Consumer-group permissions for clients that consume through a group.
run_acl --add --allow-principal User:logstash --operation READ --group demo-logstash-consumers
run_acl --add --allow-principal User:akhq --operation READ --group demo-akhq-consumers

echo "[OK] ACL application completed."
