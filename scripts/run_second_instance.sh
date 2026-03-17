#!/usr/bin/env bash

set -euo pipefail

DEFAULT_GAME_EXE="/data/SteamLibrary/steamapps/common/lucid-blocks/lucid-blocks/lucid-blocks.exe"

resolve_game_exe() {
  local game_exe="${GAME_EXE:-$DEFAULT_GAME_EXE}"
  if [[ ! -f "$game_exe" ]]; then
    printf 'Lucid Blocks executable not found: %s\n' "$game_exe" >&2
    return 1
  fi
  printf '%s\n' "$game_exe"
}

GAME_EXE=$(resolve_game_exe)
STEAM_ROOT="${STEAM_ROOT:-/home/parkersettle/.local/share/Steam}"
PROTON_BIN="${PROTON_BIN:-$STEAM_ROOT/steamapps/common/Proton - Experimental/proton}"
SECOND_PREFIX="${SECOND_PREFIX:-/data/SteamLibrary/steamapps/compatdata/lucid-blocks-coop-second}"
SECOND_SHADERCACHE="${SECOND_SHADERCACHE:-/data/SteamLibrary/steamapps/shadercache/lucid-blocks-coop-second}"
GAME_LIBRARY_DIR=$(dirname "$(dirname "$GAME_EXE")")

if [[ ! -f "$PROTON_BIN" ]]; then
  printf 'Proton binary not found: %s\n' "$PROTON_BIN" >&2
  exit 1
fi

mkdir -p "$SECOND_PREFIX"
mkdir -p "$SECOND_SHADERCACHE"

printf 'Launching second Lucid Blocks instance...\n'
printf 'Game exe: %s\n' "$GAME_EXE"
printf 'Second prefix: %s\n' "$SECOND_PREFIX"
printf 'Second shadercache: %s\n' "$SECOND_SHADERCACHE"

steam-run env \
  STEAM_COMPAT_APP_ID=3495730 \
  STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT" \
  STEAM_COMPAT_DATA_PATH="$SECOND_PREFIX" \
  STEAM_COMPAT_INSTALL_PATH="$GAME_LIBRARY_DIR" \
  STEAM_COMPAT_LIBRARY_PATHS="$STEAM_ROOT/steamapps:/data/SteamLibrary/steamapps" \
  STEAM_COMPAT_MOUNTS="$STEAM_ROOT/steamapps/common/Proton - Experimental:$STEAM_ROOT/steamapps/common/SteamLinuxRuntime_sniper" \
  STEAM_COMPAT_SHADER_PATH="$SECOND_SHADERCACHE" \
  STEAM_COMPAT_TOOL_PATHS="$STEAM_ROOT/steamapps/common/Proton - Experimental:$STEAM_ROOT/steamapps/common/SteamLinuxRuntime_sniper" \
  STEAM_COMPAT_TRANSCODED_MEDIA_PATH="$SECOND_SHADERCACHE" \
  STEAM_COMPAT_MEDIA_PATH="$SECOND_SHADERCACHE/fozmediav1" \
  STEAM_FOSSILIZE_DUMP_PATH="$SECOND_SHADERCACHE/fozpipelinesv6/steamapprun_pipeline_cache" \
  "$PROTON_BIN" waitforexitandrun "$GAME_EXE"
