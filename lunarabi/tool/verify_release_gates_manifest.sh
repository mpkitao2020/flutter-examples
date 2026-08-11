#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/docs/evidence/release_gates.manifest.json"

python3 - "$MANIFEST" "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

manifest = Path(sys.argv[1])
root = Path(sys.argv[2])

if not manifest.is_file():
    print(
        "ERROR: docs/evidence/release_gates.manifest.json is missing; "
        "every release gate must have status=closed plus evidence, owner, date, and signOff.",
        file=sys.stderr,
    )
    sys.exit(1)

try:
    data = json.loads(manifest.read_text())
except json.JSONDecodeError as exc:
    print(f"ERROR: invalid JSON in {manifest.relative_to(root)}: {exc}", file=sys.stderr)
    sys.exit(1)

gates = data.get("gates")
if not isinstance(gates, list) or not gates:
    print("ERROR: release gates manifest must contain a non-empty gates array", file=sys.stderr)
    sys.exit(1)

errors = []
required = ("evidence", "owner", "date", "signOff")
for index, gate in enumerate(gates):
    name = gate.get("name") or f"gate[{index}]"
    if gate.get("status") != "closed":
        errors.append(f"{name}: status=closed required")
    for key in required:
        value = gate.get(key)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"{name}: {key} is required")

if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    sys.exit(1)

print("OK: every release gate is closed with evidence")
PY
