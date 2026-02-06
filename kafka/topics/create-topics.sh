#!/usr/bin/env bash
set -euo pipefail

TOPICS_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/topics.yml"

KAFKA_CONTAINER="${KAFKA_CONTAINER:-kafka-broker01}"
BOOTSTRAP_SERVERS="${BOOTSTRAP_SERVERS:-10.10.4.131:9092,10.10.4.132:9092}"

if [[ ! -f "${TOPICS_FILE}" ]]; then
  echo "[ERROR] topics.yml not found: ${TOPICS_FILE}"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] docker command not found"
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${KAFKA_CONTAINER}$"; then
  echo "[ERROR] Kafka container '${KAFKA_CONTAINER}' not found on this host."
  echo "Set KAFKA_CONTAINER env var to the broker container name on this host."
  exit 1
fi

parse_topics() {
  awk '
    $1=="-" && $2=="name:" {name=$3; gsub(/"/,"",name)}
    $1=="partitions:" {p=$2}
    $1=="replication_factor:" {r=$2; print name "|" p "|" r}
  ' "${TOPICS_FILE}"
}

echo "[INFO] Creating topics using bootstrap servers: ${BOOTSTRAP_SERVERS}"

while IFS='|' read -r name partitions rf; do
  echo "[INFO] Ensuring topic exists: ${name}"
  docker exec "${KAFKA_CONTAINER}" bash -lc "
    /opt/kafka/bin/kafka-topics.sh --bootstrap-server '${BOOTSTRAP_SERVERS}' \
      --create --if-not-exists \
      --topic '${name}' \
      --partitions '${partitions}' \
      --replication-factor '${rf}'
  "
done < <(parse_topics)

echo "[OK] Topic creation completed."
