#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   tool/package_dmg.sh "<path-to-app>.app" [output.dmg]
# Example:
#   tool/package_dmg.sh "build/macos/Build/Products/Release/Prism ToDo.app" "dist/Prism-ToDo-macos.dmg"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <app_path> [output_dmg]" >&2
  exit 1
fi

APP_PATH="$1"
OUT_DMG="${2:-dist/Prism-ToDo-macos.dmg}"

if [[ ! -d "$APP_PATH" || "${APP_PATH##*.}" != "app" ]]; then
  echo "[ERROR] app_path must be a .app directory: $APP_PATH" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
STAGING_DIR="$WORKDIR/dmg-root"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

mkdir -p "$(dirname "$OUT_DMG")"
VOLUME_NAME="$(basename "$OUT_DMG" .dmg)"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$OUT_DMG" >/dev/null

echo "[OK] DMG created: $OUT_DMG"
echo "[INFO] Includes Applications shortcut for drag-and-drop install."
