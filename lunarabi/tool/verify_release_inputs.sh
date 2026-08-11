#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=()

add_error() {
  errors+=("$1")
}

validate_env_inputs() {
  python3 - <<'PY' || return 1
import os
import sys
from urllib.parse import urlparse

errors = []

def placeholder(host: str) -> bool:
    normalized = host.lower()
    return (
        not normalized
        or normalized == "localhost"
        or normalized.endswith(".localhost")
        or normalized.endswith(".example")
        or normalized.endswith(".invalid")
    )

for key in ("LUNARABI_WEB_BASE_URL", "LUNARABI_API_BASE_URL"):
    value = os.environ.get(key, "")
    parsed = urlparse(value)
    if not value:
        errors.append(f"{key} is required")
    elif parsed.scheme != "https" or not parsed.netloc or placeholder(parsed.hostname or ""):
        errors.append(f"{key} must be an absolute https URL with a production host")

host_key = "LUNARABI_DEEP_LINK_HOST"
host = os.environ.get(host_key, "")
if not host:
    errors.append(f"{host_key} is required")
elif (
    host.strip() != host
    or "://" in host
    or "/" in host
    or "\\" in host
    or ":" in host
    or placeholder(host)
):
    errors.append(f"{host_key} must be a production host without scheme, port, or path")

if errors:
    for error in errors:
        print(f"ERROR: {error}")
    sys.exit(1)
print("OK: release URL environment is valid")
PY
}

check_native_hosts() {
  local host="${LUNARABI_DEEP_LINK_HOST:-}"
  local manifest="$ROOT/android/app/src/main/AndroidManifest.xml"
  if ! grep -Fq 'android:host="${deepLinkHost}"' "$manifest"; then
    add_error "AndroidManifest.xml must use android:host=\"\${deepLinkHost}\""
  fi
  if grep -Fq '.example' "$manifest"; then
    add_error "AndroidManifest.xml still contains .example"
  fi

  for file in "$ROOT/ios/Runner/Runner.entitlements" "$ROOT/ios/Runner/Runner.Release.entitlements"; do
    if grep -Eiq '\.example|\.invalid' "$file"; then
      add_error "${file#$ROOT/} still contains placeholder applinks"
    fi
    if [[ -n "$host" ]] && ! grep -Fq "applinks:$host" "$file"; then
      add_error "${file#$ROOT/} does not contain applinks:$host; run tool/materialize_ios_deeplink_host.sh"
    fi
  done
}

check_android_signing() {
  local props="$ROOT/android/keystore.properties"
  local missing=()
  local store_file="${LUNARABI_ANDROID_STORE_FILE:-$(read_property "$props" storeFile)}"

  [[ -n "$store_file" ]] || missing+=("LUNARABI_ANDROID_STORE_FILE/storeFile")
  [[ -n "${LUNARABI_ANDROID_STORE_PASSWORD:-}" || -n "$(read_property "$props" storePassword)" ]] || missing+=("LUNARABI_ANDROID_STORE_PASSWORD/storePassword")
  [[ -n "${LUNARABI_ANDROID_KEY_ALIAS:-}" || -n "$(read_property "$props" keyAlias)" ]] || missing+=("LUNARABI_ANDROID_KEY_ALIAS/keyAlias")
  [[ -n "${LUNARABI_ANDROID_KEY_PASSWORD:-}" || -n "$(read_property "$props" keyPassword)" ]] || missing+=("LUNARABI_ANDROID_KEY_PASSWORD/keyPassword")

  if [[ "${#missing[@]}" -ne 0 ]]; then
    add_error "Android release signing inputs are missing: ${missing[*]}"
  fi

  if [[ -n "$store_file" ]]; then
    local resolved_store_file="$store_file"
    if [[ "$resolved_store_file" != /* ]]; then
      resolved_store_file="$ROOT/android/app/$resolved_store_file"
    fi
    if [[ ! -r "$resolved_store_file" ]]; then
      add_error "Android release signing store file is not readable: $store_file"
    fi
  fi
}

read_property() {
  local file="$1"
  local key="$2"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  sed -n -E "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*(.+)[[:space:]]*$/\1/p" "$file" | sed -n '1p'
}

if ! validate_env_inputs; then
  add_error "release URL environment validation failed"
fi

if ! "$ROOT/tool/forbid_release_placeholders.sh"; then
  add_error "production Firebase files still contain placeholders"
fi

if ! "$ROOT/tool/forbid_firebase_options.sh"; then
  add_error "Dart FirebaseOptions usage is forbidden in release builds"
fi

check_native_hosts
check_android_signing

if ! "$ROOT/tool/verify_release_gates_manifest.sh"; then
  add_error "release gates manifest is not closed"
fi

if [[ "${#errors[@]}" -ne 0 ]]; then
  printf 'ERROR: release preflight failed:\n' >&2
  for error in "${errors[@]}"; do
    printf ' - %s\n' "$error" >&2
  done
  exit 1
fi

echo "OK: release inputs are ready"
