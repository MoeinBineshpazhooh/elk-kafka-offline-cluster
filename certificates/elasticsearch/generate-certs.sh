#!/usr/bin/env bash
set -euo pipefail

# Generates:
# - A Certificate Authority (CA)
# - Transport certificates (node-to-node)
# - HTTP certificates (client-to-node)
#
# Output structure:
# certificates/elasticsearch/generated/
# ├── ca/
# │   ├── ca.crt
# │   └── ca.key
# ├── transport/
# │   ├── es01-transport.p12
# │   ├── es02-transport.p12
# │   └── es03-transport.p12
# └── http/
#     ├── es01-http.p12
#     ├── es02-http.p12
#     └── es03-http.p12

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTANCES_YML="${SCRIPT_DIR}/instances.yml"

OUT_DIR="${SCRIPT_DIR}/generated"
CA_DIR="${OUT_DIR}/ca"
HTTP_DIR="${OUT_DIR}/http"
TRANSPORT_DIR="${OUT_DIR}/transport"

ES_IMAGE="${ES_IMAGE:-elastic/elasticsearch:9.2.4}"

mkdir -p "${CA_DIR}" "${HTTP_DIR}" "${TRANSPORT_DIR}"

if [[ ! -f "${INSTANCES_YML}" ]]; then
  echo "[ERROR] instances.yml not found: ${INSTANCES_YML}"
  exit 1
fi

echo "[INFO] Using Elasticsearch image: ${ES_IMAGE}"
echo "[INFO] Output dir: ${OUT_DIR}"

# 1) Generate CA (PEM)
if [[ -f "${CA_DIR}/ca.crt" && -f "${CA_DIR}/ca.key" ]]; then
  echo "[SKIP] CA already exists at ${CA_DIR}"
else
  echo "[INFO] Generating CA (PEM)..."
  docker run --rm \
    -u 0 \
    -v "${SCRIPT_DIR}:/work" \
    "${ES_IMAGE}" \
    bash -lc '
      set -e
      cd /work
      /usr/share/elasticsearch/bin/elasticsearch-certutil ca --pem --out /work/generated/ca/ca.zip
      unzip -o /work/generated/ca/ca.zip -d /work/generated/ca/
      # Expected paths: /work/generated/ca/ca/ca.crt and ca.key
      cp -f /work/generated/ca/ca/ca.crt /work/generated/ca/ca.crt
      cp -f /work/generated/ca/ca/ca.key /work/generated/ca/ca.key
    '
  rm -f "${CA_DIR}/ca.zip" || true
fi

# 2) Generate node certs (PKCS#12) for Transport
echo "[INFO] Generating Transport certificates (PKCS#12)..."
docker run --rm \
  -u 0 \
  -v "${SCRIPT_DIR}:/work" \
  "${ES_IMAGE}" \
  bash -lc '
    set -e
    cd /work
    /usr/share/elasticsearch/bin/elasticsearch-certutil cert \
      --in /work/instances.yml \
      --ca-cert /work/generated/ca/ca.crt \
      --ca-key  /work/generated/ca/ca.key \
      --out /work/generated/transport/transport.zip \
      --pass ""
    unzip -o /work/generated/transport/transport.zip -d /work/generated/transport/unzipped
  '

# Move files into stable names
# The unzip output structure varies; we normalize names to: es0X-transport.p12
find "${TRANSPORT_DIR}" -type f -name "*.p12" -delete || true
for n in es01 es02 es03; do
  p12_path="$(find "${TRANSPORT_DIR}/unzipped" -type f -name "${n}.p12" -o -name "${n}.p12" 2>/dev/null | head -n1 || true)"
  if [[ -z "${p12_path}" ]]; then
    # Some versions place files under unzipped/<instance>/<instance>.p12
    p12_path="$(find "${TRANSPORT_DIR}/unzipped" -type f -path "*/${n}/*.p12" | head -n1 || true)"
  fi
  if [[ -z "${p12_path}" ]]; then
    echo "[ERROR] Could not locate transport cert for ${n} under ${TRANSPORT_DIR}/unzipped"
    exit 1
  fi
  cp -f "${p12_path}" "${TRANSPORT_DIR}/${n}-transport.p12"
done

# 3) Generate node certs (PKCS#12) for HTTP
echo "[INFO] Generating HTTP certificates (PKCS#12)..."
docker run --rm \
  -u 0 \
  -v "${SCRIPT_DIR}:/work" \
  "${ES_IMAGE}" \
  bash -lc '
    set -e
    cd /work
    /usr/share/elasticsearch/bin/elasticsearch-certutil http \
      --in /work/instances.yml \
      --ca-cert /work/generated/ca/ca.crt \
      --ca-key  /work/generated/ca/ca.key \
      --out /work/generated/http/http.zip \
      --pass ""
    unzip -o /work/generated/http/http.zip -d /work/generated/http/unzipped
  '

find "${HTTP_DIR}" -type f -name "*.p12" -delete || true
for n in es01 es02 es03; do
  # elasticsearch-certutil http typically produces files under: unzipped/elasticsearch/<name>/http.p12
  p12_path="$(find "${HTTP_DIR}/unzipped" -type f -name "http.p12" -path "*/${n}/*" | head -n1 || true)"
  if [[ -z "${p12_path}" ]]; then
    echo "[ERROR] Could not locate http.p12 for ${n} under ${HTTP_DIR}/unzipped"
    exit 1
  fi
  cp -f "${p12_path}" "${HTTP_DIR}/${n}-http.p12"
done

echo ""
echo "[OK] Certificates generated successfully."
echo ""
echo "Generated files:"
echo "- CA:        ${CA_DIR}/ca.crt"
echo "- CA key:    ${CA_DIR}/ca.key   (KEEP SECRET)"
echo "- Transport: ${TRANSPORT_DIR}/es01-transport.p12, es02-transport.p12, es03-transport.p12"
echo "- HTTP:      ${HTTP_DIR}/es01-http.p12, es02-http.p12, es03-http.p12"
echo ""
echo "Next step:"
echo "Copy CA + node certs to each ES node under /opt/elastic/es0X/certs/"
