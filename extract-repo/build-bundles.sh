#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash extract-repo/build-bundles.sh [OUTDIR] [REF]
# Examples:
#   bash extract-repo/build-bundles.sh dist/bundles HEAD
#   bash extract-repo/build-bundles.sh dist/bundles v1.0.0

OUTDIR="${1:-dist/bundles}"
REF="${2:-HEAD}"
PREFIX="elk-bundle/"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

mkdir -p "${OUTDIR}"

archive() {
  local name="$1"; shift
  local paths=("$@")
  echo "==> Building ${OUTDIR}/${name}.tar.gz (ref=${REF})"
  git -C "${REPO_ROOT}" archive \
    --format=tar.gz \
    -o "${OUTDIR}/${name}.tar.gz" \
    --prefix="${PREFIX}" \
    "${REF}" \
    "${paths[@]}"
}

# Role bundles
archive "es-controller"  elasticsearch kafka env scripts docs certificates
archive "kafka-broker"   kafka env scripts docs
archive "kibana"         kibana env scripts docs certificates
archive "logstash"       logstash env scripts docs certificates
archive "ui"             ui env docs

# Checksums (nice for offline integrity verification)
if command -v sha256sum >/dev/null 2>&1; then
  (cd "${OUTDIR}" && sha256sum *.tar.gz > SHA256SUMS)
elif command -v shasum >/dev/null 2>&1; then
  (cd "${OUTDIR}" && shasum -a 256 *.tar.gz > SHA256SUMS)
else
  echo "WARNING: sha256sum/shasum not found; skipping checksum file."
fi

echo
echo "Done. Output directory: ${OUTDIR}"
ls -lah "${OUTDIR}" | sed -n '1,200p'
