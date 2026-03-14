#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_DIR="$SCRIPT_DIR/build"

mkdir -p "$BUILD_DIR"

nix-shell -p pkgsCross.mingwW64.stdenv.cc --run \
  "x86_64-w64-mingw32-gcc -shared -O2 -s -o \"$BUILD_DIR/libgdblocks.windows.template_release.double.x86_64.dll\" \"$SCRIPT_DIR/gdblocks_proxy.c\""

printf 'Built proxy DLL: %s\n' "$BUILD_DIR/libgdblocks.windows.template_release.double.x86_64.dll"
