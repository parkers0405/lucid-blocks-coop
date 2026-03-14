#!/usr/bin/env bash

set -euo pipefail

GAME_DIR="${1:-/data/SteamLibrary/steamapps/common/lucid-blocks/lucid-blocks}"
DLL="$GAME_DIR/libgdblocks.windows.template_release.double.x86_64.dll"

if [[ ! -f "$DLL" ]]; then
  printf 'DLL not found: %s\n' "$DLL" >&2
  exit 1
fi

if ! command -v nix-shell >/dev/null 2>&1; then
  printf 'nix-shell is required for radare2\n' >&2
  exit 1
fi

run_r2() {
  local cmd="$1"
  nix-shell -p radare2 --run "r2 -2qc \"$cmd\" \"$DLL\""
}

printf 'DLL: %s\n' "$DLL"
printf 'SHA256: '
sha256sum "$DLL" | cut -d' ' -f1
printf '\n'

printf 'Chunk-gen debug string:\n'
run_r2 'aaa; iz~stall: chunk gen'
printf '\n'

printf 'update_loaded_region candidate xrefs:\n'
run_r2 'aaa; axt @ 0x1800f2978'
printf '\n'

printf 'Caller window around set_loaded_region_center logic:\n'
run_r2 'aaa; pd 40 @ 0x18005d0e8'
printf '\n'

printf 'update_loaded_region function summary:\n'
run_r2 'aaa; afn World_update_loaded_region 0x18005e610; afn World_set_loaded_region_center 0x18005c3b0; afl~World_'
