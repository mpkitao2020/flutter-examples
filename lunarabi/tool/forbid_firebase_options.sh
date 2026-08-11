#!/usr/bin/env bash
# Fails if Dart code introduces FlutterFire-generated FirebaseOptions.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$ROOT/lib"
PATTERNS=(
  'firebase_options.dart'
  'DefaultFirebaseOptions'
  'Firebase.initializeApp(options:'
  'FirebaseOptions('
)
found=0
for pat in "${PATTERNS[@]}"; do
  if grep -R --include='*.dart' -n -F "$pat" "$LIB" 2>/dev/null; then
    echo "FORBIDDEN: matched pattern: $pat"
    found=1
  fi
done
if [[ -f "$LIB/firebase_options.dart" ]]; then
  echo "FORBIDDEN: lib/firebase_options.dart exists"
  found=1
fi
if [[ "$found" -ne 0 ]]; then
  echo "Use native google-services.json / GoogleService-Info.plist only."
  exit 1
fi
echo "OK: no Dart FirebaseOptions usage under lib/"
