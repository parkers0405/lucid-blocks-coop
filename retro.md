# Lucid Blocks mod retro

## 2026-11-11: gameplay responsiveness audit
Routine save/ack paths had been treated as global gameplay barriers. Capturing terrain snapshots before waiting, separating inventory actions from movement/camera, and using the engine's FIFO background file work removed measured routine input freezes while preserving host validation and atomic receipts. Partial stacks now conserve their remainder; chest controls fit the actual small logical viewport; cached lease modes avoid repeated subtree walks. No service, dependency or player setup was added.

The useful checks were the real local host/guest scenario and focused delay/invalidation regressions. They exposed saved dirty data being mistaken for residency, stale object installation after ownership commit, an old nonce rejecting reconnect, an active autosave losing its revision result when hosting starts, and loading-player disabled state being latched by handoff. The prevention edits are the native residency queries, pending-install marker/canonical offscreen bundles, session guards, revision-cache generation/file identity, and loading-safe handoff gates. Final exact-artifact LAN completes19functional assertions, including reconnect and independent dimensions; packed contracts361+68, installer23 and chest29 pass. Strict native Steam/shutdown failures remain separate. A later native fusion lookup crash exposed shared packed-array detachment risk and capture during loading: private startup table and loading-safe routine/explicit capture paths now complete that scenario. Exclusive crash causation remains unproven; evidence is in playtest.md.

The main wasted work was pursuing a worker/native corruption hypothesis before locating the fixture's double-free, and then running several memory-heavy native checks concurrently on a16GB machine. Guarded deferred UI cleanup fixed the first; serial verification distinguishes current deadline/environment failures from functional assertions. Routine maintenance remains two commands; only combat/render changes need the separate rendered check. Exact total development time/tokens were not measured. Two-account Steam behavior and subjective player feedback remain outside this local evidence.

## 2026-10-27: broad readability correction
The first readability pass was too narrow. User wanted the full update covered and the whole process retold simply. Reviewed all added modules and our changed manager/world/entity/tool/test paths. Revised15 implementation/test/tool files with clear names, direct validation steps, visible save fields and simpler test role flows; already-direct hooks remain. Full simple history is process-log-revise.md, coverage is revision-coverage.md.
First strict run383assertions+67scripts passed, plus compile-only LANfixture, purechunk17 andtooling3. Independent review found no significant issue. No repairs used. What worked: exact coverage prevented another chest-only pass. No native/crash/Steam gameplay claim, no changed save/protocol contract or install/push/release. This style applies only here. Time/tokens not measured.


## 2026-10-27: readability revision
Problem: some new co-op code used nested expressions, long checks and leftover helpers. Changed chest transfer code to plain branches, removed unused storage methods and an ignored option, and made comments/checks easier to read. Kept the file-write and co-op safety code.

First strict run passed379 assertions and67 script checks; tooling3pass. Six new chest checks cover the rewritten branches. No repair rounds used. No new runtime failure or reusable engine lesson. Full gameplay remains blocked by the earlier crash; it was not retried. This style request applies only here. Total time/tokens not measured; no native/main/push/install/release change.


## 2026-10-27: autonomous local finish reached bounded runtime roadblock
Strict373assertions/67scripts and tooling3pass establish metadata, typed save restore and disconnected chest cleanup contracts; local commits retained. Actual separate-process smoke failed after host world/transport startup: native loaded-region center call crashed twice; source cause unverified. Headless icon baking stall was fixture-only and bypassed with the existing skip flag; no rendered UI claim. Two smoke repairs consumed, no further retry/native expansion.

What worked: strict gates exposed a real preservation-map decode bug and inactive-ENet cleanup error; small regressions now pass. Atomic fixture markers and explicit ModPack prevent false/stale evidence. What did not: passing helper fixtures did not establish gameplay startup. Independent review and owned-process cleanup completed. Full gameplay/failure/soak remain blocked, real Steam/human checks unavailable. Exact time/token cost not measured; no new workflow/guide-rule changes. User requested final log then stop; no automatic continuation.


## 2026-10-27: private respawn metadata checkpoint2451c54
Strict369 assertions and67 script checks passed with original5.2 binaries. Optional metadata in the existing atomic instance ledger preserves owner isolation, distinguishes absent from intentional empty and survives transient FIRMAMENT resets. Coverage merges preserve another explorer's unloaded changes. Independent review found no additional blocker.

Two repair rounds: reserved GDScript local name, then generic-to-typed Dictionary fixture assignment. The retained fail-fast script gate and typed-copy regression prevent repeating these failures. No relaxed error gates or native edits. Exact time/token cost not measured. Full separate-process gameplay remains next; real two-account Steam and human playfeel remain unavailable.


## 2026-10-27: lease integration strict PASS and requested stop
Strict632f5b14 passed311assertions and67scripts with original5.2binaries; tooling3pass. Repair2 eliminated the resource exit error through mod-owned drop serialization/restoration avoiding confirmed unparented Inventory allocations; four allocation/format/motion regressions passed. Exact verbose resource identity was not directly observed. Two repair rounds used for the resolved lease branch; no gate relaxation/native changes.

What worked: atomic storage primitives, focused native/drop and real-presence regressions, independent read-only review, explicit changed-input retries and periodic local commits. What did not: the first fixture omitted the new lease contract, and inherited drop serializers were unsuitable for frequent mod capture. Preventive edits are the explicit fixture lease and mod helpers/tests now retained. Exact total time/tokens not measured; no credential entry or required user setup steps.

User explicitly requested the last commit then stop. Private respawn metadata and actual two-process scenario remain unfinished; no overall gameplay/install/release claim. No workflow/agent/guide-rule change applied.

## 2026-10-27: first integrated lease attempt79c6 (repair1 pending)
Goal: mod-only authority handoff, exact pickup conservation and private visits. Expanded pure26 passed. Combined79c6 strict failed: four region fixture assertions and a missing-key script error prevented that suite completion; new lease runtime15, instance25, canonical12 and admission83 completed with zero failures. A global success marker did not override the strict error gate.

Root cause observed: old region fixture did not declare the newly required live lease/epoch. Repair1 supplies legitimate authority input. Review also found stale replicas can resume on disconnect without canonical deletion install. Presence finding was narrowed after source inspection: capture/helper semantics were inconsistent; controlled locks and downed revival require distinct presence/targetability/mutation rules. Production regressions are being added; no pass claimed yet.

Setup failure: game reported Steam IPC unavailable. Steam was launched, but sandbox process enumeration hid the external process; an unsandboxed read confirmed it running. An attempted old SteamAPI_Init ctypes preflight failed before initialization because that export is absent; no further guessed-signature calls were made. The unnecessary keepalive helper was stopped. Next game startup must prove IPC success.

Cost: one combined run, one repair round in progress, no credential entry or manual user steps. Prevention: seed the fixture's actual lease contract; keep strict per-suite/error checks; verify Steam process state in the matching permission context. No native/renderer fixes, installations or outward actions. Pipeline/agent-rule changes remain unapproved and unapplied.


## 2026-10-26: durable lease/pickup primitive buildb478275
Twenty isolated assertions passed on pinned4.6double (work/lease-primitive-probe/stdout.txt, empty stderr.txt). Atomic inventory/drop removal/receipt and durable lease-owner/epoch CAS passed failure/replay/corruption checks; no runtime authority claim. Independent bounded primitive review found no additional atomicity issue. Caller review found exactUUID replacement erases a saved record through preserveexit and initialized synced-drop reuse repeats signal connections; sourcewriter corrects both before integrated test. No combined attempt or exhausted repair branch. User-required periodic passing increments produced b478275 while manager integration remains dirty. No user steps, no native/install/push actions; exact process cost not measured.

## 2026-10-26: private/chest lifecycle build11b6bc5
Goal unchanged: complete mod-only co-op. Strict1509ba30 passed239assertions+67scripts. Review hypotheses answered: chest ACK lifetime must outlive UI (forcedclose/duplicate/wrongACK/timeout fixtures now pass); missing private ledger is not evidence of empty legacyworld (ambiguity/provenowner/namespaced source checks pass). No runtime failure or repair loop in this increment. One sourcewriter plus root verification; no user steps; total tokens/calendar cost not recorded. Remaining runtime splitbrain, terrain movingboundary and durable host pickup receipt need implementation before live two-process scenario. No agent/workflow/guide-rule change applied.

## 2026-10-26: shared-ledger integration and installed-target drift (verification ongoing)
Ambition tier: not applicable to this compatibility mod. Goal: functional two-player co-op through mod overrides only; no native/base-install edits. Gameplay completion remains unverified.

Hypotheses answered: atomic inventory/object persistence can survive interrupted pickup (pure ledger11checks and combined instance20checks0failures). Whole-process distance authority is insufficient: read-only review identifies host0/guest200/entity100 simultaneous simulation and synced-drop promotion loss. Live handoff remedy remains pending.

Failure: combined84fd admission73had16failures and follow-on RPCerrors despite storage/region/profile/canonical passing. Root cause observed: Steam changed installedgame from5.1to5.2 overnight; strict versionguard correctly rejected it. Cost: one combined run; zero user steps. Caught by admissionfixture and runtimeversion. Prevention: rawbuilder should record/check installed target identity before expensive staging; proposed below. Prior protocol already required volatile buildidentity checks, so this was missed application of an existing rule, not a new rule requirement.

What worked: strict markers exposed failed admission despite COOP_BUILD_CHECK_OK; isolatedprofiles preserved personal saves; scripts-only recovery compared390scripts and bounded relevantdelta to overriddenBubblebear/newHwobbb. Reused unchanged nativeDLLhash and existing205+66contract evidence.

Process cost: one source writer plus independent review/QA mapping; exact total tokens/time not recorded. One changed-target compatibility repair passed in c1b7ee; existing two-repair maximum retained. No installation, publication or player metrics.

| Proposed pipeline change | File | Evidence | Status |
|---|---|---|---|
| Fail raw build preflight when embedded game version differs from mod target; retain target fingerprint in log | scripts/build_raw_mod.ps1 |84fd mismatched target ran full suite before rejection | proposed; implement within build tooling when source ownership available |

Historical detailed debugging record: retrospective.md and process-log.md. No agent/workflow/guide-rule edit proposed or applied in this entry.

## 2026-10-31: controlled startup and restoration fixes
Goal: resume interrupted local mod-only verification. Removed obsolete host radius expansion (db9794e), then corrected terrain loading cleanup and checkpoint/lease disabled-state restoration (c08bcf7). Final strict contract build passed388+67, tooling3passed, independent reviews found no significant issue.

Root causes: host enlarged the radius after pool initialization; matched repaired host survived20frames at radius48/buffer80. Terrain cleanup asked for active identity while deliberately disabling the loading flag that identity sampling requires. The canonical fixture had mocked that dependency away; it now exercises it. A lease could capture a checkpoint's temporary disabled state as the original baseline; four regressions preserve active locks and both originally enabled/disabled states.

What worked: reused precise controls and installed hashes; original files/saves stayed read-only; one source writer, bounded independent review, passing local commits. What failed: early admission smoke could complete before initial lease; strengthened readiness exposed the latches. One early final save failed intermittently; no claim that all checkpoint races are eliminated.

Evidence: final actual two-process5b8064fc passed8gameplay assertions, both markers/exit0, lease1 and durable revision2->3, loader/player enabled. STRICTFAILED10shutdown errors per role. Original/offline controls also report10; exact causes remain unproven and no errors were suppressed. Renewed two repairs consumed; stopped at gate. Expanded exploration/travel/chest/reconnect/failure/soak remainUNRUN; no native/inherited-shutdown investigation or install/push/merge/release. Final owned runtime audit0.

Cost: two strict builds and six serial scenario/control runs in this continuation; reused earlier controls and toolchain instead of rebuilding native tools. Exact tokens/time not measured. Prevention edits are the dependency-respecting canonical fixture, lease baseline assertions and actual initial-lease readiness gate. General lesson proposed: cleanup identity must remain available while its subsystem is paused. No guide/workflow rule change applied without approval.

## 2026-11-10: review preparation with deferred multiplayer validation
Goal: finish autonomous local work for code review while deferring other-player/user-input tests. Reused pinned tools and existing contracts: strict 388 assertions plus 67 scripts passed; installer 42 and build safeguards 3/2/1 passed. Candidate hash exactly matches the earlier package. Independent bounded review found documentation/public-tree cleanup issues, no additional concrete production blocker.

What worked: a source read and full retained contracts avoided speculative production edits. Corrected stale target/counts and documented source builds instead of presenting inherited dist as current. What did not: the first sandbox ENet run failed; existing machine evidence correctly identified the environment boundary. A transient installer replacement failed once and passed unchanged on rerun; no root cause or production bug claimed. Explicit marker/error gates were retained.

No gameplay hypothesis was newly answered. Prior full-world shutdown errors and missing exploration/private travel/chest/reconnect/soak verification remain visible. Other-player/human checks are deferred under current user scope. Exact cost/time not measured; one independent review, two contract attempts, one installer retry, no native rebuild, no new code/dependency, no installation or release. No shared guide/workflow rule changes.

## 2026-11-10: simpler solo-maintainer workflow
Retained gameplay functionality while removing1,307net code lines (320production),10test files and3routine verification commands. Definition-only helpers and disabled native loading were removable; live authentication/persistence/ownership protocols were retained. Store tests now use the actual production APIs. Consolidating primitive coverage into runtime fixtures removes duplicate maintenance without hiding corruption/coverage/item-loss boundaries. One wire rejection replaces seven repeated wire setups; the field-validation table remains intact.

Evidence: baseline migration388+67PASS; final lean326+67PASS; installer/build23PASS; independent review clear. What failed: consolidated fixture reused an existing local name and failed parse; renamed it and made suite loading fail promptly. Sandbox file replacement also failed on unchanged installer code; normal file-access rerun passed. No claim of an installer defect or gameplay certification. Earlier world shutdown errors remain unresolved and their now-retired reproduction harness is recoverable in history.

Cost: reused pinned toolchain, no new dependencies/native build. Two final-suite attempts for the new fixture collision; no production fix loop. Future routine work is the local -Test build and installer test after tooling changes, plus optional combat-render check only when relevant. No shared guide/workflow rule change.
