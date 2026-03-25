#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   release_config_audit.sh <app_path> [dmg_path]
# Example:
#   release_config_audit.sh build/macos/Build/Products/Release/Prism\ ToDo.app dist/Prism-ToDo-v0.2.1-hotfix-network.dmg

APP_PATH="${1:-}"
DMG_PATH="${2:-}"

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "[ERROR] app_path missing or not found: $APP_PATH" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
REPORT="${WORKDIR}/release-config-audit.txt"

cleanup() {
  if [[ -n "${DMG_PATH:-}" ]]; then
    hdiutil detach "$WORKDIR/mnt" >/dev/null 2>&1 || true
  fi
  rm -rf "$WORKDIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

mkdir -p "$WORKDIR/mnt"

check_app() {
  local app="$1"
  local label="$2"

  echo "===== ${label} =====" >> "$REPORT"
  echo "App: $app" >> "$REPORT"

  # 1) 不允许把 settings.json 作为默认配置打进包
  local settings_files
  settings_files=$(find "$app" -type f -name "settings.json" || true)
  if [[ -n "$settings_files" ]]; then
    echo "[FAIL] bundled settings.json found:" >> "$REPORT"
    echo "$settings_files" >> "$REPORT"
    return 1
  else
    echo "[OK] no bundled settings.json" >> "$REPORT"
  fi

  # 2) 不允许把已知测试网关写进产物
  local hit_url
  hit_url=$(grep -R --binary-files=text -n "cc.sub.258000.sbs" "$app" || true)
  if [[ -n "$hit_url" ]]; then
    echo "[FAIL] found test gateway marker in bundle" >> "$REPORT"
    echo "$hit_url" >> "$REPORT"
    return 1
  else
    echo "[OK] test gateway marker not found" >> "$REPORT"
  fi

  # 3) 不允许把已知测试 token 前缀写进产物
  local hit_token
  hit_token=$(grep -R --binary-files=text -n "sk-b668ee" "$app" || true)
  if [[ -n "$hit_token" ]]; then
    echo "[FAIL] found test token marker in bundle" >> "$REPORT"
    echo "$hit_token" >> "$REPORT"
    return 1
  else
    echo "[OK] test token marker not found" >> "$REPORT"
  fi

  # 4) 记录默认配置来源说明（代码事实）
  echo "[INFO] default config source: SettingsStorage loads/writes ~/Library/Application Support/.../prism_todo/settings.json at runtime." >> "$REPORT"
  echo "[INFO] bundle contains code defaults only (AISettings), not user/test settings file." >> "$REPORT"

  return 0
}

check_app "$APP_PATH" "APP" >> /dev/null

if [[ -n "$DMG_PATH" ]]; then
  if [[ ! -f "$DMG_PATH" ]]; then
    echo "[ERROR] dmg_path not found: $DMG_PATH" >&2
    exit 2
  fi

  hdiutil attach "$DMG_PATH" -mountpoint "$WORKDIR/mnt" -nobrowse -readonly >/dev/null
  DMG_APP=$(find "$WORKDIR/mnt" -maxdepth 2 -type d -name "*.app" | head -n 1)
  if [[ -z "$DMG_APP" ]]; then
    echo "[FAIL] no .app found in dmg: $DMG_PATH" >> "$REPORT"
    cat "$REPORT"
    exit 1
  fi

  check_app "$DMG_APP" "DMG" >> /dev/null
fi

cat "$REPORT"
