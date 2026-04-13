#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
PROJECT_DIR="${PROJECT_DIR:-$ROOT_DIR/mod/overrides}"

resolve_godot_bin() {
  if [[ -n "${GODOT_EXPORT_BIN:-}" && -x "${GODOT_EXPORT_BIN}" ]]; then
    printf '%s\n' "$GODOT_EXPORT_BIN"
    return 0
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

  printf 'Godot export binary not found for avatar normalization.\n' >&2
  return 1
}

main() {
  local godot_bin
  godot_bin=$(resolve_godot_bin)

  local -a avatar_ids
  if (( $# > 0 )); then
    avatar_ids=("$@")
  elif [[ -n "${AVATAR_NORMALIZE_IDS:-}" ]]; then
    # shellcheck disable=SC2206
    avatar_ids=(${AVATAR_NORMALIZE_IDS})
  else
    avatar_ids=(pim)
  fi

  local avatar_id
  for avatar_id in "${avatar_ids[@]}"; do
    printf 'Normalizing avatar %s\n' "$avatar_id"
    "$godot_bin" --headless --path "$PROJECT_DIR" --script res://coop_mod/animation_workflow/avatar_normalizer.gd -- "$avatar_id"
  done
}

main "$@"
