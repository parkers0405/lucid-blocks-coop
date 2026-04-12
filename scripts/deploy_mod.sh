#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

DEFAULT_GAME_EXE="$HOME/.local/share/Steam/steamapps/common/lucid-blocks/lucid-blocks/lucid-blocks.exe"
LEGACY_GAME_EXE="/data/SteamLibrary/steamapps/common/lucid-blocks/lucid-blocks/lucid-blocks.exe"
DEFAULT_MOD_NAME="lucid-blocks-coop.pck"
DEFAULT_PROJECT_DIR="$ROOT_DIR/mod/overrides"
DEFAULT_DIST_DIR="$ROOT_DIR/dist"

build_and_install_native_patch() {
  if [[ "${INSTALL_NATIVE_PATCH:-1}" == "0" ]]; then
    return 0
  fi
  if [[ ! -f "$ROOT_DIR/scripts/build_native_patch_extension.sh" ]]; then
    return 0
  fi

  printf 'Building native multi-region patch\n'
  "$ROOT_DIR/scripts/build_native_patch_extension.sh"
  "$ROOT_DIR/scripts/install_native_patch_extension.sh"
}

build_and_copy_pack() {
  local godot_bin="$1"
  local project_dir="$2"
  local target_path="$3"
  local dist_target_path="$4"
  local label="$5"

  printf 'Building %s\n' "$target_path"
  "$godot_bin" --headless --path "$project_dir" --export-pack "Linux/X11" "$target_path"
  printf 'Installed %s pack to %s\n' "$label" "$target_path"
  cp -f "$target_path" "$dist_target_path"
  printf 'Copied %s pack to %s\n' "$label" "$dist_target_path"
}

resolve_godot_bin() {
  if [[ -n "${GODOT_EXPORT_BIN:-}" ]]; then
    if [[ -x "$GODOT_EXPORT_BIN" ]]; then
      printf '%s\n' "$GODOT_EXPORT_BIN"
      return 0
    fi
    printf 'Configured Godot binary is not executable: %s\n' "$GODOT_EXPORT_BIN" >&2
    return 1
  fi

  local candidates=(
    "$ROOT_DIR/work/tools/godot-4.6/editor/Godot_v4.6-stable_linux.x86_64"
    "$(command -v godot4 2>/dev/null || true)"
    "$(command -v godot 2>/dev/null || true)"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf 'Godot export binary not found. Set GODOT_EXPORT_BIN or install godot4.\n' >&2
  return 1
}

resolve_game_exe() {
  local configured_game_exe="${GAME_EXE:-}"
  if [[ -n "$configured_game_exe" ]]; then
    if [[ ! -f "$configured_game_exe" ]]; then
      printf 'Lucid Blocks executable not found: %s\n' "$configured_game_exe" >&2
      return 1
    fi
    printf '%s\n' "$configured_game_exe"
    return 0
  fi

  local candidates=(
    "$DEFAULT_GAME_EXE"
    "$LEGACY_GAME_EXE"
  )

  local game_exe
  for game_exe in "${candidates[@]}"; do
    if [[ -f "$game_exe" ]]; then
      printf '%s\n' "$game_exe"
      return 0
    fi
  done

  printf 'Lucid Blocks executable not found. Checked: %s\n' "${candidates[*]}" >&2
  return 1
}

main() {
  local godot_bin
  godot_bin=$(resolve_godot_bin)

  local game_exe
  game_exe=$(resolve_game_exe)

  local project_dir="${PROJECT_DIR:-$DEFAULT_PROJECT_DIR}"
  if [[ ! -d "$project_dir" ]]; then
    printf 'Mod project directory not found: %s\n' "$project_dir" >&2
    exit 1
  fi

  local mods_dir="${MODS_DIR:-$(dirname "$game_exe")/mods}"
  local mod_name="${MOD_NAME:-$DEFAULT_MOD_NAME}"
  local target_path="$mods_dir/$mod_name"
  local dist_dir="${DIST_DIR:-$DEFAULT_DIST_DIR}"
  local dist_target_path="$dist_dir/$mod_name"

  build_and_install_native_patch

  mkdir -p "$mods_dir" "$dist_dir"
  find "$mods_dir" -maxdepth 1 -type f \
    \( -name 'lucid-blocks-coop*.pck' -o -name 'zz-lucid-blocks-coop*.pck' -o -name 'zzz-lucid-blocks-command-chat*.pck' \) \
    -delete
  find "$dist_dir" -maxdepth 1 -type f \
    \( -name 'lucid-blocks-coop*.pck' -o -name 'zz-lucid-blocks-coop*.pck' -o -name 'zzz-lucid-blocks-command-chat*.pck' \) \
    -delete

  build_and_copy_pack "$godot_bin" "$project_dir" "$target_path" "$dist_target_path" "coop mod"
}

main "$@"
