#!/usr/bin/env bash
set -euo pipefail

ROOT="${LUNARABI_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HOST="${LUNARABI_DEEP_LINK_HOST:-}"

python3 - "$ROOT" "$HOST" <<'PY'
import plistlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
host = sys.argv[2]

def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)

normalized = host.lower()
if not host:
    fail("LUNARABI_DEEP_LINK_HOST is required")
if host.strip() != host or "://" in host or "/" in host or "\\" in host or ":" in host:
    fail("LUNARABI_DEEP_LINK_HOST must be host-only")
if (
    normalized == "localhost"
    or normalized.endswith(".localhost")
    or normalized.endswith(".example")
    or normalized.endswith(".invalid")
):
    fail("LUNARABI_DEEP_LINK_HOST must not be a placeholder")

for rel in (
    "ios/Runner/Runner.entitlements",
    "ios/Runner/Runner.Release.entitlements",
):
    path = root / rel
    with path.open("rb") as fh:
        plist = plistlib.load(fh)
    plist["com.apple.developer.associated-domains"] = [f"applinks:{host}"]
    with path.open("wb") as fh:
        plistlib.dump(plist, fh, sort_keys=False)
    print(f"materialized {rel}: applinks:{host}")
PY
