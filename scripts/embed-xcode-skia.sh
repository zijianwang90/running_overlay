#!/bin/bash
# Runs after Xcode links/copies resources and before its final app signing.
set -euo pipefail

if [[ "${SKIA_ENABLED:-YES}" != "YES" ]]; then
  # A reused build directory must not retain a previously embedded renderer.
  rm -f "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/libskia.dylib"
  rm -rf "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/Legal/Skia"
  exit 0
fi
: "${SKIA_DIR:?Set SKIA_DIR to the pinned m159 dual-backend Metal SDK}"
python3 "${SRCROOT}/scripts/validate-skia-sdk.py" "$SKIA_DIR"
app="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
library="${app}/Contents/Frameworks/libskia.dylib"
legal="${app}/Contents/Resources/Legal/Skia"
mkdir -p "$(dirname "$library")" "$legal"
cp "$SKIA_DIR/lib/libskia.dylib" "$library"
cp "$SKIA_DIR/LICENSE" "$legal/LICENSE"
cp "$SKIA_DIR/THIRD_PARTY_NOTICES.txt" "$legal/THIRD_PARTY_NOTICES.txt"
cp "$SKIA_DIR/licenses/skcms-LICENSE" "$legal/skcms-LICENSE"

if [[ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" ]]; then
  identity="${EXPANDED_CODE_SIGN_IDENTITY:--}"
  sign_command=(/usr/bin/codesign --force --sign "$identity")
  if [[ "${ENABLE_HARDENED_RUNTIME:-NO}" == "YES" && "$identity" != "-" ]]; then
    sign_command+=(--options runtime)
  fi
  "${sign_command[@]}" "$library"
fi
python3 "${SRCROOT}/scripts/validate-packaged-skia.py" "$app"
