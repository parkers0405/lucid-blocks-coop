#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
EXT_DIR="$ROOT_DIR/native_patch/runtime_extension"
GODOT_CPP_DIR="$EXT_DIR/godot-cpp"
GODOT_CPP_REF="${GODOT_CPP_REF:-master}"
DOUBLE_API_FILE="$EXT_DIR/extension_api.double.json"

build_in_nix_shell() {
  local workdir="$1"
  local command="$2"

  nix-shell \
    -p scons python3 pkgsCross.mingwW64.stdenv.cc pkgsCross.mingwW64.windows.mcfgthreads pkgsCross.mingwW64.windows.mcfgthreads.dev \
    --run "MCFGTHREAD_INCLUDE=\$(python3 - <<'PY'
import glob
paths = glob.glob('/nix/store/*mcfgthread*x86_64-w64-mingw32*/include')
print(paths[0] if paths else '')
PY
) MCFGTHREAD_LIB=\$(python3 - <<'PY'
import glob
paths = glob.glob('/nix/store/*mcfgthread*x86_64-w64-mingw32*/lib')
print(paths[0] if paths else '')
PY
) && cd \"$workdir\" && export MCFGTHREAD_INCLUDE=\"\$MCFGTHREAD_INCLUDE\" MCFGTHREAD_LIB=\"\$MCFGTHREAD_LIB\" C_INCLUDE_PATH=\"\$MCFGTHREAD_INCLUDE\${C_INCLUDE_PATH:+:\$C_INCLUDE_PATH}\" CPLUS_INCLUDE_PATH=\"\$MCFGTHREAD_INCLUDE\${CPLUS_INCLUDE_PATH:+:\$CPLUS_INCLUDE_PATH}\" LIBRARY_PATH=\"\$MCFGTHREAD_LIB\${LIBRARY_PATH:+:\$LIBRARY_PATH}\" CFLAGS=\"-isystem \$MCFGTHREAD_INCLUDE \$NIX_CFLAGS_COMPILE\" CXXFLAGS=\"-isystem \$MCFGTHREAD_INCLUDE \$NIX_CFLAGS_COMPILE\" CPPFLAGS=\"-isystem \$MCFGTHREAD_INCLUDE \$NIX_CFLAGS_COMPILE\" LDFLAGS=\"-L\$MCFGTHREAD_LIB \${LDFLAGS:-}\" && $command"
}

if [[ ! -d "$GODOT_CPP_DIR" ]]; then
  git clone --depth=1 --branch "$GODOT_CPP_REF" https://github.com/godotengine/godot-cpp.git "$GODOT_CPP_DIR"
fi

if [[ ! -f "$GODOT_CPP_DIR/SConstruct" ]]; then
  printf 'godot-cpp checkout is missing SConstruct: %s\n' "$GODOT_CPP_DIR" >&2
  exit 1
fi

python3 - <<PY
import json
from pathlib import Path

source = Path(${GODOT_CPP_DIR@Q}) / "gdextension" / "extension_api.json"
target = Path(${DOUBLE_API_FILE@Q})

data = json.loads(source.read_text(encoding="utf-8"))
data["header"]["precision"] = "double"
target.write_text(json.dumps(data, indent=4) + "\n", encoding="utf-8")
PY

build_in_nix_shell "$GODOT_CPP_DIR" "scons platform=windows target=template_release precision=double arch=x86_64 custom_api_file=\"$DOUBLE_API_FILE\""
build_in_nix_shell "$EXT_DIR" "GODOT_CPP_DIR=\"$GODOT_CPP_DIR\" scons platform=windows target=template_release precision=double arch=x86_64 build_library=no custom_api_file=\"$DOUBLE_API_FILE\""

shopt -s nullglob
matches=("$EXT_DIR"/build/coopnativepatch/libcoopnativepatch*.dll)
if [[ ${#matches[@]} -eq 0 ]]; then
  printf 'Built native patch DLL not found under %s\n' "$EXT_DIR/build/coopnativepatch" >&2
  exit 1
fi

printf 'Built native patch DLL: %s\n' "${matches[0]}"
