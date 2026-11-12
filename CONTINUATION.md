# Lucid Blocks continuation — 2026-11-11

Review follow-up on fix/review-ready-compatibility is in progress; NOT READY pending confirmed pickup, checkpoint and persistence fixes and current verification. Previous packed361assertions/68scripts, installer23, chest29 and exact-artifact two-process19functional assertions remain historical evidence. Strict LAN still fails offline Steam/native shutdown errors. STATE.md and playtest.md hold current verification and limits. No service, external worker executable or player configuration is required.

Normal maintenance remains scripts/build_mod.ps1 -Test with the pinned Godot/GDRE/game paths, then tests/test_install.ps1 after tooling changes. Use -CombatTests after combat/render changes. Keep strict native-error results separate from completed functional assertions.

Preserve unrelated102.import changes and status-only test line endings. Original installation and personal saves remain untouched. No PR creation, actual merge, main push, installation or release is part of this update. Real two-account Steam and subjective human playfeel remain outside local evidence.

Next (2026-11-11 option-3 pass): G4/G6 need an in-memory handoff (state exchanged by RPC, install payloads built from memory, every durable write write-behind) plus a fix for the host staying frozen 14.5 s when the guest is hard-killed mid-handoff. Still to build: water_travel, quit_midaction, host-kill and terrain-on-disk checks, bad/spike/cut and failing-disk cells, the 3-repeat matrix. Run friction jobs one pair at a time (scripts/test_local_coop.ps1 enforces it); exes live in work/friction/bin/{host,guest,solo}.

Update: realistic-latency cells show the handoff needs fewer sequential round trips (design change, not job trimming); host mining in co-op needs a root cause; summarize.ps1 should exempt the open chest modal from G4. Pending: clean+fast remeasure after the save-queue fix, host-kill and terrain-on-disk checks, water_travel/quit_midaction, installer rerun.

## Resume 2026-11-12
1. Decide H9: root-cause why the host reply receive_durable_pickup never reaches the guest under the typical relay after a protocol-7 switch (reliable channel is alive; sync_canonical_terrain and sync_break_block arrive; RPC table change, priority lane, deferred install and lease_activated were each ruled out). 2. Host mining under latency (4 of 20; clean passes 20). 3. Build water_travel, quit_midaction, host-kill and install-time kill points. 4. Rerun the full matrix; status wording stays NOT READY until every gate passes in one run.
