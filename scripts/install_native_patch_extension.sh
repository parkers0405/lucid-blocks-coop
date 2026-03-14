#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$SCRIPT_DIR/common.sh"

EXT_DIR="$ROOT_DIR/native_patch/runtime_extension"
GAME_EXE=$(resolve_game_exe)
GAME_DIR=$(dirname "$GAME_EXE")
TARGET_DIR="$GAME_DIR/coop-native-patch"

shopt -s nullglob
matches=("$EXT_DIR"/build/coopnativepatch/libcoopnativepatch*.dll)
if [[ ${#matches[@]} -eq 0 ]]; then
  printf 'Built native patch DLL not found under %s\n' "$EXT_DIR/build/coopnativepatch" >&2
  exit 1
fi

DLL_PATH="${matches[0]}"
mkdir -p "$TARGET_DIR"
cp "$DLL_PATH" "$TARGET_DIR/$(basename "$DLL_PATH")"

DLL_BASENAME="$(basename "$DLL_PATH")"
GDEXT_PATH="$TARGET_DIR/coop_native_patch.gdextension"
CONFIG_PATH="$TARGET_DIR/patch_config.json"

cat > "$GDEXT_PATH" <<EOF
[configuration]

entry_symbol = "coop_native_patch_init"
compatibility_minimum = "4.6"
reloadable = false

[libraries]

windows.release.x86_64 = "$DLL_BASENAME"
EOF

if [[ ! -f "$CONFIG_PATH" ]]; then
  cat > "$CONFIG_PATH" <<EOF
{
  "enabled": false,
  "instance_radius_cap": 96,
  "instantiate_chunks_render_distance": 96
}
EOF
fi

printf 'Installed native patch extension to %s\n' "$TARGET_DIR"
