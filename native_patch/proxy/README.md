# gdblocks Proxy DLL

This is a foothold for a local native patch path.

Idea:

- rename the shipped `libgdblocks.windows.template_release.double.x86_64.dll`
  to `libgdblocks.windows.template_release.double.x86_64.original.dll`
- drop in a proxy DLL with the original filename
- forward the single exported `gdblocks_init` symbol to the renamed real DLL
- apply a world-loader patch before gameplay starts

Why this path is useful:

- the shipped GDExtension only exports `gdblocks_init`
- the proxy can be written in plain C and does not need to reimplement the
  entire extension
- it gives us a controlled place to add DLL hash checks, backups, and future
  trampoline / byte-patch logic

Current status:

- `gdblocks_proxy.c` is only a loader/forwarder skeleton
- no runtime patch is installed yet
- the actual multi-region patch still needs either:
  - a safe binary patch against the current DLL hash, or
  - a source-level rebuild from the owner-shared code
