# Handoff redesign (handoff-design.md section 4), status 2026-11-12
- [x] H0 instrumentation (517e585), H1 ordering proof (517e585), H2 terrain oracle (490e33d)
- [x] H3 commit_lease rules, H4 ownership diff (31da55d); H5 install replay, H6 checkpoint snapshot, H7 transit and epoch window, H8 pre-prepare (92af9c5)
- [ ] H8b lost hits on transit mobs: not measured (no mobs in the scenarios)
- [ ] H9 SWITCH/SWITCHED/ACTIVATED: implemented on build/h9-one-roundtrip-wip, BLOCKED by undelivered pickup replies under the relay (playtest.md 2026-11-12)
- [ ] H10 recovery and quit kill points; H11 full gate matrix; reviewer pass; README, architecture, gameplay-audit, CONTINUATION, retro updates

# Current work — gameplay quality

Review follow-up in [gameplay-audit.md](gameplay-audit.md): confirmed findings corrected, focused regressions and independent source review complete; final packed/runtime verification underway. Current status NOT READY. Historical361assertions/68scripts, installer23, chest29 and two-process19functional assertions remain in playtest.md. Next: final packed run, exact-artifact offline/LAN comparison, then record the readiness decision. Keep the maintenance workflow below.

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
