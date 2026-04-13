#!/usr/bin/env bash

set -euo pipefail

DEFAULT_GAME_EXE="$HOME/.local/share/Steam/steamapps/common/lucid-blocks/lucid-blocks/lucid-blocks.exe"
LEGACY_GAME_EXE="/data/SteamLibrary/steamapps/common/lucid-blocks/lucid-blocks/lucid-blocks.exe"

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

GAME_EXE=$(resolve_game_exe)
STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
PROTON_BIN="${PROTON_BIN:-$STEAM_ROOT/steamapps/common/Proton - Experimental/proton}"
RUNTIME_DIR="${RUNTIME_DIR:-$STEAM_ROOT/steamapps/common/SteamLinuxRuntime_sniper}"
SECOND_PREFIX="${SECOND_PREFIX:-$STEAM_ROOT/steamapps/compatdata/lucid-blocks-coop-second}"
SECOND_SHADERCACHE="${SECOND_SHADERCACHE:-$STEAM_ROOT/steamapps/shadercache/lucid-blocks-coop-second}"
COOP_PLAYER_KEY_SUFFIX="${COOP_PLAYER_KEY_SUFFIX:-second}"
GAME_LIBRARY_DIR=$(dirname "$(dirname "$GAME_EXE")")
COMPAT_LIBRARY_PATHS="$STEAM_ROOT/steamapps"

if [[ -d "/data/SteamLibrary/steamapps" ]]; then
  COMPAT_LIBRARY_PATHS="$COMPAT_LIBRARY_PATHS:/data/SteamLibrary/steamapps"
fi

if [[ ! -f "$PROTON_BIN" ]]; then
  printf 'Proton binary not found: %s\n' "$PROTON_BIN" >&2
  exit 1
fi

if [[ ! -d "$RUNTIME_DIR" ]]; then
  printf 'Steam Linux Runtime not found: %s\n' "$RUNTIME_DIR" >&2
  exit 1
fi

if ! command -v steam-run >/dev/null 2>&1; then
  printf 'steam-run not found. Try: nix-shell -p steam-run --run ./scripts/run_second_instance.sh\n' >&2
  exit 1
fi

mkdir -p "$SECOND_PREFIX"
mkdir -p "$SECOND_SHADERCACHE"

printf 'Launching second Lucid Blocks instance...\n'
printf 'Game exe: %s\n' "$GAME_EXE"
printf 'Second prefix: %s\n' "$SECOND_PREFIX"
printf 'Second shadercache: %s\n' "$SECOND_SHADERCACHE"
printf 'Coop player key suffix: %s\n' "$COOP_PLAYER_KEY_SUFFIX"

steam-run env \
  COOP_PLAYER_KEY_SUFFIX="$COOP_PLAYER_KEY_SUFFIX" \
  STEAM_COMPAT_APP_ID=3495730 \
  STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT" \
  STEAM_COMPAT_DATA_PATH="$SECOND_PREFIX" \
  STEAM_COMPAT_INSTALL_PATH="$GAME_LIBRARY_DIR" \
  STEAM_COMPAT_LIBRARY_PATHS="$COMPAT_LIBRARY_PATHS" \
  STEAM_COMPAT_MOUNTS="$STEAM_ROOT/steamapps/common/Proton - Experimental:$RUNTIME_DIR" \
  STEAM_COMPAT_SHADER_PATH="$SECOND_SHADERCACHE" \
  STEAM_COMPAT_TOOL_PATHS="$STEAM_ROOT/steamapps/common/Proton - Experimental:$RUNTIME_DIR" \
  STEAM_COMPAT_TRANSCODED_MEDIA_PATH="$SECOND_SHADERCACHE" \
  STEAM_COMPAT_MEDIA_PATH="$SECOND_SHADERCACHE/fozmediav1" \
  STEAM_FOSSILIZE_DUMP_PATH="$SECOND_SHADERCACHE/fozpipelinesv6/steamapprun_pipeline_cache" \
  "$PROTON_BIN" waitforexitandrun "$GAME_EXE"
