#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/docs/evidence/release_gates.manifest.json"

python3 - "$MANIFEST" "$ROOT" <<'PY'
import json
import sys
from datetime import date as calendar_date
from pathlib import Path
from pathlib import PurePosixPath

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
artifact_prefix = PurePosixPath("docs/evidence/artifacts")
artifacts_root = (root / "docs/evidence/artifacts").resolve()


def validate_evidence(name: str, evidence: str) -> None:
    evidence_path = PurePosixPath(evidence)
    normalized = evidence.lower()

    if "runbook" in normalized:
        errors.append(f"{name}: evidence path must not contain runbook")
    if evidence_path.parts[:2] == ("docs", "superpowers"):
        errors.append(f"{name}: evidence must not point under docs/superpowers")
    if evidence_path.suffix.lower() == ".md":
        errors.append(f"{name}: markdown documents are not evidence artifacts")
    if evidence_path.is_absolute() or ".." in evidence_path.parts:
        errors.append(f"{name}: evidence must be a relative path under docs/evidence/artifacts")
        return
    if evidence_path.parts[:3] != artifact_prefix.parts:
        errors.append(f"{name}: evidence must be under docs/evidence/artifacts")
        return

    artifact = (root / Path(evidence)).resolve()
    try:
        artifact.relative_to(artifacts_root)
    except ValueError:
        errors.append(f"{name}: evidence must stay under docs/evidence/artifacts")
        return

    if not artifact.is_file():
        errors.append(f"{name}: evidence artifact does not exist: {evidence}")
    elif artifact.stat().st_size < 32:
        errors.append(f"{name}: evidence artifact must be at least 32 bytes: {evidence}")


for index, gate in enumerate(gates):
    name = gate.get("name") or f"gate[{index}]"
    if gate.get("status") != "closed":
        errors.append(f"{name}: status=closed required")
    for key in required:
        value = gate.get(key)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"{name}: {key} is required")
    evidence = gate.get("evidence")
    if isinstance(evidence, str) and evidence.strip():
        validate_evidence(name, evidence.strip())
    raw_date = gate.get("date")
    if isinstance(raw_date, str) and raw_date.strip():
        try:
            calendar_date.fromisoformat(raw_date.strip())
        except ValueError:
            errors.append(f"{name}: date must be a valid calendar date (YYYY-MM-DD)")
    owner = gate.get("owner")
    if isinstance(owner, str) and owner.strip() and len(owner.strip()) < 3:
        errors.append(f"{name}: owner must be at least 3 characters")
    sign_off = gate.get("signOff")
    if isinstance(sign_off, str) and sign_off.strip() and len(sign_off.strip()) < 2:
        errors.append(f"{name}: signOff must be at least 2 characters")

if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    sys.exit(1)

print("OK: every release gate is closed with evidence")
PY
