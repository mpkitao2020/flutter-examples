#!/bin/bash
# Xcode Build Phase: copy flavor-specific GoogleService-Info.plist into the app bundle.
#
# Preferred CONFIGURATION names: Debug-dev, Release-stg, Profile-prod, etc.
# Fallback when using stock Flutter configs:
#   Debug   -> dev
#   Profile -> stg
#   Release -> prod
set -euo pipefail

if [[ "${CONFIGURATION}" == *-* ]]; then
  FLAVOR="${CONFIGURATION##*-}"
else
  case "${CONFIGURATION}" in
    Debug) FLAVOR=dev ;;
    Profile) FLAVOR=stg ;;
    Release) FLAVOR=prod ;;
    *)
      echo "error: Unknown CONFIGURATION=${CONFIGURATION}"
      exit 1
      ;;
  esac
fi

case "$FLAVOR" in
  dev|stg|prod) ;;
  *)
    echo "error: Unknown flavor '${FLAVOR}' from CONFIGURATION=${CONFIGURATION}"
    exit 1
    ;;
esac

SRC="${PROJECT_DIR}/config/${FLAVOR}/GoogleService-Info.plist"
DST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
echo "Copying Firebase plist (${FLAVOR}): $SRC -> $DST"
cp "$SRC" "$DST"
