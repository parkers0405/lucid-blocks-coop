# Lucid Blocks co-op state
Updated 2026-11-12. Protocol 7 candidate (one-round-trip handoff) on fix/review-ready-compatibility, local only. NOT certified READY: the broad gate matrix was dropped by decision; see PR notes and known limits below.

- Branch: fix/review-ready-compatibility. Preserve102unrelated.import edits and status-only test line endings.
- Scope: smooth two-player gameplay with compatibility/functionality retained. No PR creation, merge, main push, installation or release performed.
- Routine terrain snapshots preserve movement/camera and newer edits. Travel/quit/reconnect retain durable barriers.
- Pure file IO uses Godot built-in WorkerThreadPool/FIFO; no external worker, service, hosting or player setup.
- Pickups lock inventory actions only, conserve overflow and defer during gliding. Unchanged held/equipment slots keep instances.
- Leases use native residency queries, sticky ownership and cached node modes. Recovery reconciles durable epochs and canonical objects before new saves; stale continuations are rejected.
- Loading-safe dimension following seeds the destination anchor before native first-visit spawning. Detached entity bodies do not query physics motion.
- Chest21slots/quantity/Close fit341x256logical; dismissal releases movement immediately while retaining pending inventory acknowledgement.
- Protocol6 requires matching peers; existing save formats remain compatible.
- Packed contractsdeec58d2fdc2475d93293fcea4bd11c5 PASS361assertions+queue+68scripts, exit0/noERROR. PackageSHA256925F75C7F733919623492EF847A45B5762686162A555442F3AAA78A18F823EDC.
- Installer8e3d3fba3a94483ea406b24ef7bb9a05 PASS23 synthetic assertions. Original install and personal saves untouched.
- Chest render/click4f7ed7a24d8c4b56bbfb6dfbdf184278:29checks,0failures; source/visual review complete.
- Actual plain-artifact LAN84d749fff9804ba68dd10005676df3b7:19functional assertions PASS, both exit0. Reconnect, independent native loading, Naraka travel, following and shutdown recovery complete; no mod script/RPC/physics-space errors or crash.
- Strict LAN FAIL retained: host12/guest13errors =2/3offline Steam achievement calls+10native shutdown categories each. Exact native shutdown causes unresolved; see playtest.md.
- Final six-second input sample361frames/0disabled outside handoff vs earlier baseline361/11; max43.178ms. No broad FPS guarantee.
- Optional combat55functional assertions and visibility pass; strict8native shutdown errors remain. Baseline shader completion blocked. Expanded LAN native Steam/shutdown errors are tracked separately from gameplay assertions.
- Real two-account Steam invites and subjective human playfeel remain untested by requested scope. Dated details/failures: playtest.md; architecture.md and gameplay-audit.md describe current behavior.
- Next: correct confirmed review findings, run affected contracts and exact-artifact LAN verification, then reassess readiness. Prior passing assertions are historical evidence. No actual merge, release or installation.


## PR notes (2026-11-12)
Changed: protocol 7 handoff (PREPARE/STAGE/SWITCH/SWITCHED/ACTIVATED, only changed-owner objects pause, durable commit is write-behind); install-time edit parking and replay; ownership snapshot for profile checkpoints; commit_lease rules for tombstones and bundle inserts; fix for the host water/fire snapshot cache flood (the cause of pickup timeouts and reconnects); review fixes (bundles validated against the sender's dimension, 10 s host switch timeout, pickups of in-transit objects refused, post-T0 spawns kept by the host, failed install kicks the peer, parked-edit handling).
Tested (final tree): contracts 14 markers, 0 failures, no ERROR (new checks for switch outcomes, timeout, dimension validation, install failure kick, parking); tests/test_install.ps1 23 PASS; one typical-profile smoke (work/friction/smoke, smoke2): mine_tunnel, chest_cycle, shared_loot (30 of 30 conserved), quit_midaction (host quit 29 ms) all 0 reconnects, no lost or duplicated items, terrain oracle matches host disk; handoff_motion rerun 0 reconnects, no lock, switch p95 596 ms. One earlier handoff_motion smoke run hit a 35-minute stall (legs 2000+ s, guest "Connection timed out") that did not reproduce; treated as a machine stall, unconfirmed.
Known limits (not fixed): bad-network (150 ms, 3 % loss) host switch p95 about 800 ms and only typical-profile numbers are claimed; failing or slow disk (250 ms per job): handoff_motion spike+failing froze the host 9.5 s and its shutdown commit failed, kill_handoff recovery freeze 4.2 s, pickup ack 2.4-3.9 s on the slow disk and 0.5-0.8 s on the fast disk (limit asked 270 ms, not met); cut profile host lock 197 ms; 1-2 frames over 50 ms in some handoff cells; native error categories not in the unmodded control (ENet SYS_COMMAND_AUTH under reorder, RPC to a disconnected peer and inactive multiplayer around cut/spike shutdowns, ref_count <= N in mine_tunnel) were not root-caused; water_travel, host-kill autosave, mob and portal checks, the reorder-free control and a 3-repeat full matrix were not run. Review findings 2, 4 (partly: only guest-dimension change), 5 (post-flip validation branches partly tested), 6 (relies on the store rejecting stale expected_lease) and 7 (attack paths rely on owns_runtime_node, not separately tested) have no dedicated end-to-end test.
