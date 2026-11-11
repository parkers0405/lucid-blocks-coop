# Gameplay audit and implementation

Current objective: preserve compatibility and functionality while making routine play responsive. This request supersedes prior review-readiness claims and retired integration-test scope. No merge/install/release authorization.

## Player-facing requirements
- Ordinary movement/camera never wait for pickup, autosave, terrain checkpoint or ownership bookkeeping.
- Inventory/object acknowledgements remain ordered and duplicate-safe; disk failures preserve the last valid state.
- Chest browsing may be modal, but Close/Escape must immediately dismiss it, safely retain pending transactions and restore correct cursor behavior.
- Dimension transitions/reconnect may show loading; queues and delayed work must not leak across instances/sessions.
- Expensive IO stays off gameplay frames; unchanged state is not repeatedly saved; terrain reconciliation and ownership enforcement are bounded.

## Audit findings / queue
1. [x] Nonblocking routine terrain checkpoints; snapshot and dirty detection before network waits.
2. [x] Stable ownership during movement; no global player freezes for lease bookkeeping, bounded entity-mode updates.
3. [x] Pickup/chest inventory conflict lock separate from movement/camera; partial-stack pickups conserved.
4. [x] Serialize pure file transactions off gameplay thread, coalesce unchanged checkpoints; reject stale-session completions.
5. [x] Bound canonical cell application work, retain newer updates/epochs and environmental simulation.
6. [x] Correct combat routing by actual ownership for host/guest/split enemies and attacks on players.
7. [x] Scope/clear pending block/water/fire/storage queues at instance restore boundaries.
8. [x] Cache AnimationTree properties per graph/instance and LAN local identity per manager.
9. [x] Cross-dimension teleport ends near requested player after destination readiness.
10. [x] Chest responsive geometry, immediate dismissal, accurate pending/invalid states, safe mouse restore, modal chat/hotkeys and command discovery.
11. [x] Focused latency/slow-disk/input regressions, current pinned runtime and automated two-process gameplay evidence, independent source/UI review.

## Verification
Measure input availability and process-frame continuity under injected delayed acknowledgements/IO, check snapshot/queue isolation and transaction conservation; then exercise disposable real host/guest instances. Preserve strict completion/error gates and historical failures. A marker-only contract pass does not establish smooth gameplay. No human/other-account test is made a routine user step; unavailable external Steam evidence must remain explicit.

One source writer at a time. Preserve102unrelated.import edits and original installation/personal saves. Track measured results and blockers here and in playtest.md.

## Current evidence

Final packeddeec58d2fdc2475d93293fcea4bd11c5 passes361assertions+file queue+68scripts, exit0/noERROR. Installer23synthetic assertions and chest29click/render checks pass; source/UI reviews complete. Plain-artifact LAN84d749fff9804ba68dd10005676df3b7 completes19functional assertions, both exit0: independent loading/ownership, movement during inventory acknowledgement, successive terrain edits on host disk, reconnect, independent dimension travel, following and shutdown recovery. Final six-second sample361frames/0disabled outside handoff vs earlier baseline361/11; max43.178ms is a local observation, not general FPS certification.

Strict LAN still FAILS host12/guest13errors:2/3offline Steam achievement calls and10native shutdown categories each, matching categories previously observed in original/offline controls. Exact native causes remain unresolved. No current mod script/RPC/physics-space error or crash; no errors suppressed. A prior native fusion-table lookup crash led to a private startup array and loading-safe snapshot barriers; current same-path scenario completes. Optional combat55assertions/visibility pass but strict8shutdownerrors remain; baseline shader completion blocked. Real two-account Steam and subjective human playfeel remain excluded. Dated evidence and prior failures: playtest.md.
