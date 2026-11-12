# Lucid Blocks co-op state
Updated 2026-11-12. NOT READY (G4, G5, G6, G9 fail; conservation, terrain oracle and G8 pass). Kept tree: protocol 6 + H3-H8 + review fixes (8b8dd5a). H9 (protocol 7) is on build/h9-one-roundtrip-wip, unresolved: host reply receive_durable_pickup never reaches the guest under the relay. RESUME: root-cause H9 or lower freeze on protocol 6 (clean+fast handoff lock 233 ms vs 150 limit; typical+slow 4.4 s); host mining 4/20 under latency; build water_travel, quit_midaction, host-kill, reorder-free AUTH control. Details: playtest.md top entry.

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
