#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILES=(
  "$ROOT/android/app/src/prod/google-services.json"
  "$ROOT/ios/config/prod/GoogleService-Info.plist"
)

found=0
for file in "${FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "ERROR: missing production Firebase file: ${file#$ROOT/}"
    found=1
    continue
  fi
  if grep -Eiq 'placeholder|\.example|\.invalid' "$file"; then
    echo "ERROR: production Firebase placeholder found: ${file#$ROOT/}"
    found=1
  fi
done

if [[ "$found" -ne 0 ]]; then
  exit 1
fi

echo "OK: production Firebase files contain no placeholders"
