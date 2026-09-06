#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="${ROOT_DIR}/kibana/saved-objects.ndjson"

python3 - "$FILE" <<'PY'
import json
import sys

path = sys.argv[1]
required = {"type", "id", "attributes", "references"}

with open(path, encoding="utf-8") as handle:
    lines = [line.rstrip("\n") for line in handle if line.strip()]

if not lines:
    raise SystemExit("ERROR: saved object bundle is empty")

for number, line in enumerate(lines, 1):
    try:
        obj = json.loads(line)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"ERROR: invalid NDJSON at line {number}: {exc}")
    missing = required - obj.keys()
    if missing:
        raise SystemExit(f"ERROR: line {number} is missing: {', '.join(sorted(missing))}")

print(f"Kibana Saved Objects validation passed: {len(lines)} objects")
PY
