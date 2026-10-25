# Published native-source baseline

Status: baseline compilation PASS (exit0,2026-10-24); runtime compatibility UNVERIFIED. This DLL is not approved for installation.

Inputs:
- Source: https://github.com/kiwijuice56/lucid-blocks-gdblocks at 9fbdd398b63a9359299730a98b678bb8b4e6a671 (GPL3; preserve its license if distributing a derived DLL).
- Pinned godot-cpp submodule: 863d732f448664f192c2e143cb6778de2867a2da (Godot4.6).
- Source-provided double extension_api.json SHA256:64BBC88DFB84F68745B48713B22EDDE2215FCA45C65F347D0ADCE97EBCC74839.
- LLVM-MinGW20261020 UCRT Ubuntu22.04 x86_64 archive from https://github.com/mstorsjo/llvm-mingw/releases/tag/20261020; SHA256:55064B60B991A1E1E8090B8C2F84E82B22CFE5903D12C159D65064CF5E8AE335. Compiler reports clang23.1.4.
- SCons4.10.0 wheel from https://pypi.org/project/SCons/4.10.0/; SHA256:DF6F86828035A5C03ABCE64D4CF2F9C5CBD0051B58AF498016BC58BFC05559B0.

Tools, extracted source, outputs and logs stay under ignored work/. WSL Ubuntu uses its existing Python3; no system compiler or Python package was installed.

Baseline flags:

```text
python3 -m SCons platform=windows target=template_release precision=double arch=x86_64 use_mingw=yes use_llvm=yes custom_api_file=<absolute source>/extension_api.json -j8
```

Put the portable compiler bin directory in PATH and SCons wheel extraction directory in PYTHONPATH. Do not pass a mingw_prefix containing spaces: the pinned SCons Windows tool emits an unquoted executable path. This caused the first launch failure.

The pinned bindings godot-cpp/src/godot.cpp needs an explicit `#include <stdlib.h>` alongside stdio.h with this compiler; otherwise realloc/free are undeclared. This one-line dependency patch is the only source change in the baseline experiment. The published voxel implementation remains unchanged.

Logs: work/native-baseline-build.log and work/native-baseline-mounted-build.log for mounted-filesystem attempts; current build work/native-fast-build.log in isolated WSL /tmp/lucid-blocks-native-9fbdd398-20261024. Baseline success alone will not establish compatibility: a replacement must pass the original-pack native/runtime region and collision probes before any multi-center modification or installation. The existing RVA native patch remains disabled.


Output: work/native-baseline-output/libgdblocks.windows.template_release.double.x86_64.dll (2,863,104 bytes), SHA256:4F66CFFE038960E624773F8363452CC811A5B91156EA1CB2201BEA132C0B1FB9. Warnings remain in published source; no compilation error. No original game DLL was changed.
