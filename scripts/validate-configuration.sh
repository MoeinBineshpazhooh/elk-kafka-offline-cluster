#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v docker >/dev/null 2>&1 || {
  echo "ERROR: docker is required"
  exit 1
}

echo "==> Validating Docker Compose files"
while IFS= read -r compose_file; do
  echo "Checking ${compose_file#"$ROOT_DIR"/}"
  docker compose -f "$compose_file" config >/dev/null
done < <(find "$ROOT_DIR" -name 'docker-compose*.yml' -type f | sort)

echo "==> Checking for obvious secret placeholders in example environment files"
if grep -RInE '(^|=)(password|passwd|token|secret)=.{8,}' "$ROOT_DIR/env" --include='*.example' >/dev/null 2>&1; then
  echo "ERROR: possible non-placeholder credential found in env/*.example"
  exit 1
fi

echo "Configuration validation passed."
