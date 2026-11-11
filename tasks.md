# Current work — gameplay quality

Full audit and implementation in [gameplay-audit.md](gameplay-audit.md). The gameplay fixes and focused regressions are implemented. Final packed361assertions/68scripts, installer23, chest29 and two-process19functional assertions are recorded in playtest.md. Source and visual review completed; native Steam/shutdown limits remain explicit. Keep the normal two-command maintenance workflow below.

# Lucid Blocks work

## Current request: solo-maintainer simplification (2026-11-10)
- [x] Remove definition-only helpers and alternate test-only persistence APIs; keep production checkpoint/lease paths.
- [x] Remove the permanently disabled multi-region/native-loading implementation; keep local loading and fail-closed native guards.
- [x] Keep one supported builder, one local test switch and optional combat-render check; retire obsolete investigation modes and duplicate exporter.
- [x] Consolidate overlapping primitive tests into runtime regressions; keep authentication, atomic saves, ownership, metadata and item conservation coverage.
- [x] Verify final local build326+67, installer23 and independent review; commit the simplified branch.

## Normal maintenance
1. Run `scripts/build_mod.ps1` with matching `-Godot`, `-Gdre`, `-GameExe` paths and `-Test`.
2. Run `tests/test_install.ps1` after build/install changes.
3. Use `-CombatTests` instead of `-Test` after combat/render changes. Keep prior failures visible; a missing check is not a pass.

## Verification limits
Other-player/human tests remain deferred by user request. Automated local exploration, independent dimensions, cross-dimension following and reconnect complete19 functional assertions. Chest click/render coverage is local. Real private visits across accounts, Steam invites and subjective human playfeel remain untested. Expanded native runs retain offline Steam/shutdown errors, separately from assertion results. Its retired diagnostic harness and detailed historical work remain in Git history and dated process/playtest logs. No release certification follows from local contracts.

Original game/native libraries/personal saves stay read-only. Preserve unrelated .import edits. No PR creation, merge, main push, install or release without the user's request. Feature-branch pushes to the fork are allowed.
