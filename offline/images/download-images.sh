#!/usr/bin/env bash
set -euo pipefail

# Download all images listed in image-list.txt and save them to a single tarball.
# Run this on an ONLINE machine.

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_LIST="${BASE_DIR}/image-list.txt"
OUTPUT_TAR="${BASE_DIR}/elk-kafka-images.tar"

if [[ ! -f "${IMAGE_LIST}" ]]; then
  echo "[ERROR] image-list.txt not found at ${IMAGE_LIST}"
  exit 1
fi

echo "[INFO] Pulling images listed in ${IMAGE_LIST}"

IMAGES=()
while IFS= read -r line; do
  # Skip comments and empty lines
  [[ -z "${line}" || "${line}" =~ ^# ]] && continue
  IMAGES+=("${line}")
done < "${IMAGE_LIST}"

for img in "${IMAGES[@]}"; do
  echo "[PULL] ${img}"
  docker pull "${img}"
done

echo "[INFO] Saving images to ${OUTPUT_TAR}"
docker save -o "${OUTPUT_TAR}" "${IMAGES[@]}"

echo "[OK] Image bundle created: ${OUTPUT_TAR}"
echo "Copy this file to each air-gapped server."
