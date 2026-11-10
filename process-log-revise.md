# Lucid Blocks update: simple process log

This covers the whole update, including the parts that did not work. Exact commands and older results remain in `process-log.md` and `playtest-archive.md`.

## 1. Fork and compatibility
**Problem:** The old co-op mod no longer matched the game.

**Solution:** I kept the upstream history and worked on `fix/current-build-compatibility`. I compared our overrides with privately recovered scripts and added the missing dimension, generator, entity and water-flow interfaces. Tests use the original game resources because recovered assets can be inaccurate.

## 2. Safe build and install tools
**Problem:** A test or install could overwrite game files, and Godot sometimes exits successfully after a script error.

**Solution:** I added staging folders, separate test saves, package checks, backups and rollback tests. The builder scans errors and requires completion markers. DLL copies go at the paths the test runtime expects. The current candidate has not been installed or released. Early branch pushes are recorded in the old log; recent work is local only.

## 3. Identity and reconnect admission
**Problem:** Names and peer numbers could not safely identify returning players.

**Solution:** Steam identity comes from the transport. LAN players receive a random credential; the host stores its digest. Changes must come from the admitted sender. The handshake checks game/protocol versions and the two-player limit before gameplay.

**Trouble:** Sandbox sockets opened without delivering packets. A small control outside the sandbox proved that setup issue. Rejected connections and reconnect UI also needed fixes. Local tests pass; real two-account Steam tests have not run.

## 4. Terrain saves
**Problem:** Old dictionary patches did not match current region files. Some replies said “saved” too early.

**Solution:** Region updates now merge block, water, awake-water and fire data. New files are verified before the manifest changes. Travel waits for the source checkpoint; failure cancels the transition. Old data stays available for recovery.

**Trouble:** A fixture used the wrong awake-water size. Review also found destination ownership being set before the old world finished saving. Both were corrected and tested.

## 5. Combat compatibility
**Problem:** Current attack callers passed hit positions that old overrides did not accept. Gel hit data had also changed.

**Solution:** I updated the affected damage paths together and tested damage, knockback and feedback with original creature scenes.

**Trouble:** Shader baking overlapped tests, and some tests used the wrong clock. Correcting setup and timing made the recorded combat assertions pass. Rendered shutdown still failed. A control without co-op reproduced shutdown error categories, but did not establish every cause. Earlier native baseline experiments stayed diagnostic; their DLL was not installed. Later work stays mod-only.

## 6. Independent exploration
**Problem:** Players need separate loading areas, but must not overwrite each other's terrain.

**Solution:** Each process keeps its normal local bubble. The host assigns chunk ownership. Updates check sender, instance, lease number and revision before saving. Canonical terrain is applied back to loaded areas.

**Limit:** Ownership and terrain fixtures pass. Local native dynamics remain predictions between updates; full live exploration is not proven.

## 7. Dimensions and personal visits
**Problem:** Two personal worlds can share a dimension name but belong to different players. Visitors must keep their own inventory.

**Solution:** Private instance keys include the world owner. Travel saves the source first. Preserved objects and snapshots use the same instance key. Unclear legacy data is rejected rather than assigned to the wrong owner.

**Later fix:** Private respawn paths could gain a duplicate prefix, and Firmament resets could erase transient fields. Respawns now use the existing instance ledger. Missing data differs from an intentionally empty map. Updates cover only owned, loaded chunks. Typed copies fixed restore errors. Helper tests pass; full two-process visits remain untested.

## 8. Player, chest and object saves
**Problem:** Separate writes could lose or duplicate items after a failure. A late save could recreate a removed object.

**Solution:** Profiles, personal chests and instance objects share one atomic ledger. Revisions reject old writes. Receipts make repeated requests safe. Tombstones keep deleted objects deleted. Corrupt saves fail instead of becoming empty worlds.

## 9. Ownership handoffs and pickups
**Problem:** A new owner could start before the old owner finished saving. A pickup could remove a drop without saving the inventory.

**Solution:** The handoff freezes changes, saves the old state, commits ownership, installs bounded updates and waits for acknowledgement before resuming. Pickups save the inventory and exact drop removal together. Full inventories reject the pickup safely.

**Trouble:** One fixture lacked the new lease setup. Another run found temporary Inventory allocations in base drop-save helpers. I corrected the fixture and used mod-owned drop packing that keeps the native item/movement fields. The tests pass; that branch used its two repair rounds.

## 10. Personal chest
**Problem:** Contents and pending transfers must survive panel closure, death, timeout and reconnect.

**Solution:** I added a 21-slot chest with host designation and Store/Take controls. The manager keeps pending transactions alive after the panel closes. Failed acknowledgements enter recovery before more changes are allowed.

**Later fixes:** Saved object indexes needed typed copies. Disconnect cleanup needed to check the connection before querying ENet. Those fixtures pass. Live two-process chest use remains unverified.

## 11. Real two-process test
**Problem:** Helper tests alone do not prove playable co-op.

**Solution:** I added a host/guest harness with separate profiles, owned-process markers, atomic result files, deadlines and strict error checks. It calls real hosting and joining.

**Trouble:** The first run stalled on rendered icon baking in headless mode. Repair one skipped that UI-only fixture step and exposed the saved-index error, then a crash in `set_loaded_region_center`. Repair two used the corrected mod and fixed port setup, but hit the same native crash after host startup. Guest admission did not finish.

**Result:** Both smoke repair rounds are used up. All owned test processes stopped. The crash cause is unproven. Exploration, visits, chest, reconnect/restart and soak scenarios remain blocked. Real Steam invites and human playfeel are also unverified. This readability pass does not retry that crash or change native code.

## 12. Correcting the readability pass
**Problem:** I first treated your request as a small cleanup, mostly around the chest. That was too narrow.

**First result:** Commit `6c9d597` passed 379 assertions, 67 script checks and three tooling checks, including six added chest tests. It did not cover the whole request.

**Correction:** The new pass covers all our added modules and changed manager, game-hook, tool and test paths. It uses clearer names, direct branches and plain comments. Already-simple code stays simple; inherited code and unrelated imports stay untouched. This is a project-only style choice. The save format, protocol and safety checks stay the same. `main` remains at `57140c7abe02a921defa4184d474fb3e0ef841eb`.

## 13. Revision coverage and checks
This pass changes 15 implementation, test and tool files. Coverage includes all seven added co-op modules and our manager, world, entity, build and test changes. It is not a mechanical change to every line: already-simple code is kept rather than rewritten for appearance.

| Area | What changed or was checked |
| --- | --- |
| Identity and reconnect | Clearer admission names and separate rejection checks; sender binding and saved credentials remain. |
| Region saves | Clear migration names and commit order; verified writes, recovery data and checksums remain. |
| Chunk ownership | One small function replaces three copies of the same channel hash; four new tests cover water, awake-water, fire and seeded revisions. |
| Objects, profiles and pickups | Clear bundle/schema checks, visible drop fields and pickup passes; UUID checks, receipts, capacity and atomic writes remain. |
| Handoffs and terrain | Separate sender/epoch/activity checks and clear phase comments; freeze/save/install/ACK/resume order remains. |
| Dimensions and visits | Explicit private-load branches, migration arguments and typed map names; source-save barriers and owner isolation remain. |
| Combat and game hooks | Clear water-flow names and death-loot ordering; short attack, drop, pickup, gel, heart and cache-cube hooks were reviewed and kept. |
| Chest | A named button action replaces the nested callback. The first pass's direct Store/Take branches and six checks remain. |
| Build and test tools | Clearer launcher arguments and result checks; separate host and guest test functions; retained LAN fixture gets compile-only coverage. |
| Install and other fixtures | Reviewed all added scripts/tests. Already-direct backup, rollback, failure-injection and assertion code stays intact. No assertion was removed or weakened. |

The file-by-file coverage is in `revision-coverage.md`.

**Result:** The first broad run passed **383 assertions, no failures and 67 script checks**. The LAN fixture compiled without being executed. The isolated chunk tests passed 17 checks; PowerShell parsing and all three build-switch checks passed. No repair round was needed.

Independent review found no significant issues. It checked validation order, identity, save/ACK ordering, callbacks, the channel hash and process cleanup. No assertions were removed or softened. `main` is unchanged.

Evidence: `work/build-logs/3d21aab9ba904f2d833f37257430def1/`.
Package: `work/mod-revise-full-output/lucid-blocks-coop.pck`.
SHA256: `F5FBC38A96127C19F4D3DEE8A0ED77E7ED84CCDE1FBEE7873604A2B3063B5219`.

**Still blocked:** Full gameplay, real Steam invites and soak tests are not proved by this result. The earlier native crash and its exhausted retry limit remain. Nothing was pushed, installed or released. This pass ends after the local commit.


## 14. User-authorized gameplay diagnosis resumed
You asked to test the candidate before merging. This authorizes controlled diagnosis and local gameplay tests; it does not authorize merging, installation, native edits or an unlimited retry loop.

**Evidence reused:** strict383/67 and the retained two-process crash logs. Windows records show both earlier host crashes in the copied original gdblocks DLL at offset0x65cf8, exception0xc0000005. This identifies the faulting module/offset, not the cause. No private credentials are recorded here.

**New source findings:** the current game's World script waits for loading before changing render distance, refreshes its native chunk pool afterwards and limits center updates to once per rendered frame. The mod override does not keep those steps. Reference source shows radius changes alone do not allocate more chunks, while region loading takes chunks from a pool. An undersized pool or repeated update is a hypothesis, not a diagnosis.

**Next check:** compare three otherwise matching disposable single-process starts: original observer-only, mod offline and mod hosting. Record actual radius, position, loading and process state. Use the same original pack/DLLs and finite deadlines. No original LAN retry until a changed-input control gives a reason. This renewed diagnosis cycle allows the initial control set and at most two evidence-based repair rounds; the previous failed attempts remain recorded.

**Narrower finding:** review traced the host's old shared-bubble radius code. In the retained fixture, the native loader allocates for radius48. Hosting requests96 through `_refresh_session_load_radius`, then calls `force_reload` without refreshing the pool. This gives a concrete path to requesting more chunks than exist. The comparison will leave frame scheduling alone to avoid mixing hypotheses. A later single-variable control can hold the initialized radius if the baseline shows only hosting fails.

**Initial controls so far:** original21b9980217ec426697b43deb3e0c1e53 and mod-offline715af9e8e18a44b9bcc809d2c300e055 both loaded a real creative world and completed20 physics/process frames,2 assertions each, exit0 and completion markers. Both held radius48 and neither had the center-update crash. Both STRICT FAILED10 shutdown/resource errors with matching reported categories/counts. Those errors are retained, not ignored or whitelisted. These results support startup comparison only, not a clean gameplay build. Hosting control is next with unchanged inputs.

**Hosting control:** dc6b0f9bd51b40069df9c80354a1799b loaded/hosted (2 assertions) then crashed0xc0000005 at World center update. It logged radius48 immediately after hosting, then radius96/buffer352 before the next center work. Original and offline stayed48 and survived. No role completion marker; strictFAIL. This supports the post-load host expansion trigger.

**Repair1 input:** remove the obsolete shared host-radius expansion in mod code and test that hosting/far peers keep the normal local bubble. This matches the independent-exploration design. Do not change native code, frame gating or settings callbacks in this experiment. Root will run the strict contract suite, then the matched host control with the repaired package. One further changed-input repair remains if this branch still fails. Matching shutdown errors remain failures, never a whitelist.

**Repair1 source ready:** removed the host-radius mutator, tick call, four old constants, three saved-radius fields and the shared-bubble calculation. Guest patch reach and activity use the initialized local radius. Review found no dangling callers or significant issues. A new distant-peer activity regression raises expected strict count to384/67. The matched host fixture now also checks that radius and buffer remain unchanged after20 frames (4 assertions). Frame/settings/native code unchanged. Cheap parser/diff checks passed; strict build is running before the host control. Repair1 used; one further round remains if the same branch fails.

## 15. Resumed after usage limit — 2026-10-31
Reused section14 and its pending radius fix; no new repair round or native change. Strict build2bffdf437248410e8002c782dd7e58e0 passed384 assertions (nested admission-data26 excluded) and67 script checks; tooling3passed. Candidatework/mod-local-radius-resume-output/lucid-blocks-coop.pck SHA932F9CD6EB73771096D43611250104FD3573985F53F6E0686844D2AB83398174. Installed5.2/nativeDLL hash unchanged.
Matched repaired host control2de41135f0ef4d7697db077d3c02da21 completed4checks/0failures and exited0. Radius/buffer stayed initialized throughout20 post-load frames; previous native crash did not recur. StrictFAIL remains10shutdown/resource errors, same reported count as original/offline controls; exact cause unproved, no whitelist. This supports the removed host expansion as the startup trigger in this scenario, not general gameplay certification.
Next: retained actual host/guest smoke with the verified changed-input package. Repair1 remains the only consumed round in renewed diagnosis; one changed-input repair remains for this branch. Native/install/personal saves untouched; no merge/push/release.
The first changed-input two-process smoked90a328d progressed through actual menu join, host-world load, guest admission and agreeing transport-bound identity (host3pass, guest3pass). No earlier native startup crash. Guest final durable checkpoint returnedfalse (guest4checks/1failure); launcher stopped on failed marker and reaped both owned roles. No full smoke completion. New distinguishing check: fixture-only before/after snapshots of checkpoint/profile/lease flags, revision and status, without credentials. Do not infer a profile/lease race without that evidence. Radius review found no significant issue. The startup repair is resolved for the matched scenario; this newly reached durable checkpoint failure remains unproven.
Diagnostic a2f1b5c1539846d693930c63e18c3def completed all host3/guest4 assertions, both exit0/completion, STRICTFAIL10shutdown errors each. Guest revision1->2; before leaseinactive, after leasefrozen/busy with checkpointallowed. Prior barrier failure is intermittent; no production root cause proved. Fixture repair1 requires actual initial leaseepoch>0 and fully resumed gameplay before guest action, then retains final durable checkpoint assertion unchanged. This tests an omitted readiness prerequisite instead of treating admitted/profile-ready as full gameplay-ready. A30s deadline will expose failed lease installation; no production save/lease/gate relaxation.
Fixture prerequisite repair1 dcad8b0b784e43fdb87486a1e09d4d97 timed out initiallease-ready. Crucial result: guest epoch1, leasebusyfalse/frozenfalse, revision4, reconnectfalse/restorefalse; lease installed but a remaining worldready/preparing condition failed. No production repair justified yet. Added exact playerdisabled/loadenabled/allloaded/leasewasdisabled/preparing flags to distinguish restoration race from loading. Source candidate: _await_local_world_checkpoint temporarily disables player while awaiting profile; incoming freeze captures that temporary value, then resume can retain it. This remains a hypothesis until flags and deterministic regression establish it. Next diagnostic changes fixture output only, same package; no longer deadline.
Diagnostic df13c34fc1dd47328ea7c297dd5bcb0b: leaseepoch1, all_loadedtrue, loadingfalse, playerdisabledtrue, leasewasdisabledtrue, no busy/frozen/preparing/reconnect/restore. Source-proved loader latch: _apply_canonical_terrain disables loading, then restore guard calls get_active_dimension_instance_key -> _can_sample_player -> load_enabledfalse -> empty key, so restoration cannot run. Existing canonical fixture overrode identity/sample unconditionally and hid this dependency. Source-proved second interleaving captures a checkpoint's temporary disabled flag as lease baseline. Repair2 will restore loading immediately after successful synchronous region application and retain checkpoint baseline through lease capture/resume; tests exercise real sampling dependency and initially enabled/disabled lease baselines. This is last production repair in renewed gameplay branch; no unchanged costly retries or gate relaxation.
Repair2 source scope: one checkpoint baseline field; both host/freeze lease captures use it; resume keeps active checkpoint locked; checkpoint cleanup retains lease locks. The third lease baseline assignment is host-disconnect only (server checkpoints return before guestbusy), so it is unchanged. Canonical regression no longer mocks away the load-enabled identity dependency; four baseline/lock assertions added to lease runtime. Strict b545424d8da440e08843fde1bc7e8ada running. No new deadline, protocol, native or persistence-format change.
Repair2 strict b545424d8da440e08843fde1bc7e8ada PASS388assertions/0failures+67scripts (lease37,canonical12), original native binaries. Source/test commit c08bcf7. Candidatework/mod-runtime-restore-output/lucid-blocks-coop.pck SHA0B9AE192C10BCE1B3E891D0E007B0543702A39C8232887ABBBF5BD67D195B157. Independent review found no significant issue; lease cancellation assertions do not replace full guest RPC integration. Final bounded integration5b8064fc2ec744ce84a3d997997c02fb now running. No further same-branch production repair after this round without new authorization; no native or shutdown-suppression work.
Final integration5b8064fc2ec744ce84a3d997997c02fb: host3/0 andguest5/0 gameplay assertions, both completion markers/exit0. Guest before/after durable checkpoint: leaseepoch1, loadingtrue/allloadedtrue, playerdisabledfalse, revision2->3; no pending/lease/reconnect/restore flags. Original crash and observed loading/player latches did not recur. STRICTFAIL remains10shutdown/resource errors per role; no error whitelist. Final owned-runtime audit0 across11launchedrolePIDs. Renewed two-repair budget exhausted; stop at strict shutdown boundary, no inherited/native investigation. Expanded exploration/travel/chest/reconnect/restart/failures/soak remainUNRUN, realtwo-accountSteam/human unavailable. User install/saves untouched; no merge/push/release.

## 16. PR preparation — 2026-11-10
User requested all remaining autonomous local work until ready to open a PR, deferring tests involving other players or their input. Reviewed source against current design/architecture; no additional concrete production blocker in identity, ledger/chest lifecycle, runtime lease and travel checkpoint paths. No source change or new dependency was needed.

Strict contract build db2e550018b04ad392279a5e66786697 passed 388 assertions, 67 script checks and explicit completion/exit/error gates. Sandbox attempt ef06bfd6e1c440fcbc8dd33795fd2a54 could not communicate over local ENet; unchanged suite passed with socket access. Installer first attempt encountered a Windows replacement error; unchanged repeat passed 42 assertions. Build switches 3, shader deadlines 2 and native timeout 1 passed. Candidate work/pr-ready-output/lucid-blocks-coop.pck hash 0B9AE192C10BCE1B3E891D0E007B0543702A39C8232887ABBBF5BD67D195B157 matches the prior candidate.

Corrected stale README evidence, source-build instructions and architecture target. Removed tracked local instructions while preserving the local file; cleaned unrelated implementation-history references from project records. STATE/tasks/CONTINUATION now distinguish code-review readiness from release verification. Older strict gameplay shutdown failures remain unresolved, not whitelisted or rerun. Full exploration, private visits, chest/reconnect/failure/soak and Steam/human verification remain explicitly unverified. Original install, native libraries, personal saves and user .import edits untouched. No PR opened, merge, main push, installation or release performed.

Remote reconciliation: fetched cleaned remote checkpoint 97b0365 after a non-fast-forward push rejection. Retained the old local feature branch; created fix/review-ready-compatibility from the verified final tree with cleaned checkpoint as parent. No force-push, existing-branch rewrite, main change or source-tree change. This avoids restoring discarded historical project metadata while retaining all current mod code and verification records.

