#!/bin/bash
# Xcode Build Phase: copy flavor-specific GoogleService-Info.plist into the app bundle.
# Expects CONFIGURATION names like Debug-dev, Release-stg, Profile-prod.
set -euo pipefail
FLAVOR="${CONFIGURATION##*-}"
case "$FLAVOR" in
  dev|stg|prod) ;;
  *)
    echo "error: Unknown flavor in CONFIGURATION=$CONFIGURATION (expected *-dev|*-stg|*-prod)"
    exit 1
    ;;
esac
SRC="${PROJECT_DIR}/config/${FLAVOR}/GoogleService-Info.plist"
DST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
echo "Copying $SRC -> $DST"
cp "$SRC" "$DST"
