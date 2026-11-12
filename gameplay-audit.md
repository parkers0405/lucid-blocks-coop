# Gameplay audit and implementation

Current objective: preserve compatibility and functionality while making routine play responsive. This request supersedes prior review-readiness claims and retired integration-test scope. No merge/install/release authorization.

## 2026-11-11 review follow-up

Status: NOT READY; handoff freeze gates G4 and G6 still fail after the option-3 pass (write-behind commit, hysteresis); see playtest.md. The review's larger impairment matrix and numerical budgets are proposals, not measured results.

- Confirmed against1644054: pickup gameplay lock and pre-await race (F1/F2), shared routine/durable checkpoint lock and stale disabled-state restoration (F3/F4), loading during handoff (F5), discarded active-write results (F6), synchronous store access (F7), whole-namespace handoff reads (F8), and pose-driven routine rewrites (F9).
- F9 correction: save_checkpoint itself reads the ledger once; additional reads occur in surrounding helpers. Avoid attributing two reads to that function.
- Red packed run112b81a1634a4d33930e331cc9681f63: pickup-lock and routine-barrier regressions fail against unchanged1644054. The first queue assertion errored on the expected null; guarded standalone replay in work/review-red-queue reports SAVE_QUEUE_RESULT failures=1, exit1, empty stderr.
- Fresh original controlcce173ae7c4b4acba91fc58550571266:2checks,0failures,exit0; strict FAIL11error lines. Preserve these for the final error comparison.
- Preserve native loading/capture safety. Deferring a handoff is safer than capturing terrain while native workers are streaming. Synchronous world-loader metadata callbacks require caller/context validation before any async conversion.

| Finding | Implemented correction / retained limit |
|---|---|
| F1 | Separate pickup protection from gameplay locks; defer conflicting item-use/drop input, preserve concurrent tool wear with sparse ACKs, queue further pickups. Deferred actions retain item identity and clear across travel/disable. |
| F2 | Claim UUID before awaits and protect the ledger transaction; restore original drop mode/merge state once and release claims on all exits. |
| F3/F4 | Separate routine checkpoint state, reserve durable barriers before draining routine work, and restore disabled state only from a checkpoint that actually locks movement. |
| F5 | Defer handoffs during streaming and abort/resume if loading restarts during awaited work. Routine capture deliberately retains the native-loading guard. |
| F6 | Deliver started-write results after invalidation and reconcile same-save pickup/chest outcomes; retain queued local checkpoints and log discarded obsolete session jobs. |
| F7 | Queue active snapshot/rebase/migration/respawn reads and cache the private-owner roster. Synchronous native loader callbacks drain queued work before metadata reads; loading-only IO and small chest-access JSON remain synchronous. |
| F8 | Select requested regions/chunks on the file worker before returning a handoff payload. |
| F9 | Five-second routine personal cadence, dictionary comparison instead of two ledger serializations, and durable-priority FIFO. This reduces contention; it is not a measured network-latency guarantee. |

Additional checks: retire nonresident guest grants through durable ownership handoff, let the chest panel own Escape once, and clear completed direct-travel status. Independent source review found no further significant issue. Lease resume coverage is a focused state-restoration unit test, not full streaming-handoff evidence.

## Player-facing requirements
- Ordinary movement/camera never wait for pickup, autosave, terrain checkpoint or ownership bookkeeping.
- Inventory/object acknowledgements remain ordered and duplicate-safe; disk failures preserve the last valid state.
- Chest browsing may be modal, but Close/Escape must immediately dismiss it, safely retain pending transactions and restore correct cursor behavior.
- Dimension transitions/reconnect may show loading; queues and delayed work must not leak across instances/sessions.
- Expensive IO stays off gameplay frames; unchanged state is not repeatedly saved; terrain reconciliation and ownership enforcement are bounded.

## Audit findings / queue
The checked items below describe the previous implementation pass. The 2026-11-11 follow-up confirms remaining pickup input locks/races, checkpoint lock interference and file-queue issues; those checks do not establish merge readiness. Current follow-up evidence belongs in playtest.md.

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

## 2026-11-12 review follow-up
Fixed after the fresh review: aborted installs no longer discard parked edits, replay checks the cell is loaded, the batched and pending block-change paths honour parking, the pending scope no longer resets at a handoff, ownership hashes ignore int/float differences. H9-only findings (post-T0 spawns, tombstoned-but-installed bundles, failed host install after the guest flipped) are not applicable on this tree and remain open for the H9 branch.

Update 2026-11-12: H9 review findings 1, 4, 5, 6 are implemented (installing chunks marked early, in-transit pickups refused, post-T0 spawns kept by the host, failed host install kicks the guest). Findings 4 and 5 have no end-to-end regression, only the helper check for 4.
