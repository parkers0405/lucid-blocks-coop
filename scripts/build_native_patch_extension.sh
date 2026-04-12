#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
EXT_DIR="$ROOT_DIR/native_patch/runtime_extension"
GODOT_CPP_DIR="$EXT_DIR/godot-cpp"
GODOT_CPP_REF="${GODOT_CPP_REF:-master}"
DOUBLE_API_FILE="$EXT_DIR/extension_api.double.json"

shopt -s nullglob
existing_matches=("$EXT_DIR"/build/coopnativepatch/libcoopnativepatch*.dll)
if [[ "${FORCE_REBUILD_NATIVE_PATCH:-0}" != "1" && ${#existing_matches[@]} -gt 0 ]]; then
  existing_dll="${existing_matches[0]}"
  if ! find "$EXT_DIR/extension" "$EXT_DIR/SConstruct" "$0" -newer "$existing_dll" -print -quit | grep -q .; then
    printf 'Using existing native patch DLL: %s\n' "$existing_dll"
    exit 0
  fi
fi

build_in_nix_shell() {
  local workdir="$1"
  local command="$2"

  nix-shell \
    -p scons python3 pkgsCross.mingwW64.stdenv.cc pkgsCross.mingwW64.windows.mcfgthreads pkgsCross.mingwW64.windows.mcfgthreads.dev \
    --run "cd \"$workdir\" && $command"
}

patch_godot_cpp_sconstruct() {
  local sconstruct_path="$1"

  python3 - <<PY
from pathlib import Path

path = Path(${sconstruct_path@Q})
text = path.read_text(encoding='utf-8')
marker = 'env.PrependENVPath("PATH", os.getenv("PATH"))\n'
injection = '''env.PrependENVPath("PATH", os.getenv("PATH"))\nfor key, value in os.environ.items():\n    if key.startswith("NIX_"):\n        env["ENV"][key] = value\nfor key in ("MINGW_PREFIX", "TMPDIR", "TMP", "TEMP"):\n    if key in os.environ:\n        env["ENV"][key] = os.environ[key]\n'''

if marker not in text:
    raise SystemExit(f"Expected marker not found in {path}")

if 'key.startswith("NIX_")' not in text:
    text = text.replace(marker, injection, 1)
    path.write_text(text, encoding='utf-8')
PY
}

if [[ ! -d "$GODOT_CPP_DIR" ]]; then
  git clone --depth=1 --branch "$GODOT_CPP_REF" https://github.com/godotengine/godot-cpp.git "$GODOT_CPP_DIR"
fi

if [[ ! -f "$GODOT_CPP_DIR/SConstruct" ]]; then
  printf 'godot-cpp checkout is missing SConstruct: %s\n' "$GODOT_CPP_DIR" >&2
  exit 1
fi

rm -f "$GODOT_CPP_DIR/include/mcfgthread" "$GODOT_CPP_DIR/include/include"

patch_godot_cpp_sconstruct "$GODOT_CPP_DIR/SConstruct"

python3 - <<PY
import json
from pathlib import Path

source = Path(${GODOT_CPP_DIR@Q}) / "gdextension" / "extension_api.json"
target = Path(${DOUBLE_API_FILE@Q})

data = json.loads(source.read_text(encoding="utf-8"))
data["header"]["precision"] = "double"
target.write_text(json.dumps(data, indent=4) + "\n", encoding="utf-8")
PY

build_in_nix_shell "$GODOT_CPP_DIR" "scons platform=windows target=template_release precision=double arch=x86_64 use_mingw=yes custom_api_file=\"$DOUBLE_API_FILE\""
build_in_nix_shell "$EXT_DIR" "GODOT_CPP_DIR=\"$GODOT_CPP_DIR\" scons platform=windows target=template_release precision=double arch=x86_64 use_mingw=yes build_library=no custom_api_file=\"$DOUBLE_API_FILE\""

matches=("$EXT_DIR"/build/coopnativepatch/libcoopnativepatch*.dll)
if [[ ${#matches[@]} -eq 0 ]]; then
  printf 'Built native patch DLL not found under %s\n' "$EXT_DIR/build/coopnativepatch" >&2
  exit 1
fi

printf 'Built native patch DLL: %s\n' "${matches[0]}"
