#!/usr/bin/env bash
set -euo pipefail

# Load the prebuilt image bundle (elk-kafka-images.tar) on an AIR-GAPPED server.

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE="${BASE_DIR}/elk-kafka-images.tar"

if [[ ! -f "${BUNDLE}" ]]; then
  echo "[ERROR] Image bundle not found: ${BUNDLE}"
  echo "Copy elk-kafka-images.tar from the online machine first."
  exit 1
fi

echo "[INFO] Loading images from ${BUNDLE}"
docker load -i "${BUNDLE}"

echo "[OK] Images loaded successfully."
docker images | grep -E "(elastic/elasticsearch|elastic/kibana|elastic/logstash|apache/kafka|tchiotludo/akhq|kafbat/kafka-ui)" || true
