# Full update readability pass — coverage

Base used: 57140c7. Starting checkpoint: 6c9d597. This is a pass over our update's interfaces and changed sections, not a rewrite of every line or an independent gameplay certification. Inherited manager/UI/avatar code and unrelated imports are outside this pass. No protocol, save keys, ownership rules, native files, original install or main branch changed.

## Production modules: all seven covered

- `session_identity.gd`: renamed admission locals to player_key, issued_token and saved_key; plain comment explains why a newly issued token must be saved before admission. Same Steam/LAN branches, token hashing and duplicate checks.
- `region_checkpoint.gd`: named migration region/chunk collections by purpose; explained the payload-before-manifest commit; removed confusing region_namespace wording from errors. Existing validation, checksums, verified rename, migration precedence and retained legacy source stay explicit.
- `chunk_authority.gd`: moved the identical four-channel hash into one small `_chunk_fingerprint` function used by changed/accept/seed. Keeps channel order, lease state, revisions, batching and ownership rules. Four added tests cover water/awake/fire changes and a complete canonical seed.
- `instance_entities.gd`: split the final nested bundle predicate into root and node checks. The module remains one validator; no storage or extra indirection.
- `personal_store.gd`: split lease schema/type/size checks into readable steps; named the two pickup passes and explained all-or-nothing capacity. Existing atomic checkpoint, UUID transfer/tombstone, respawn merge, receipt and chest code retained. The prior 6c9d597 pass already made chest transfer/source/destination flow explicit; no forced rewrite of that now-straight code.
- `personal_chest.gd`: replaced the nested transfer button closure with one named `_request_transfer` action. Slot/quantity/revision are still read when pressed, the same busy lock is checked, and the same deferred manager command is sent. Existing UI/process/close flow is otherwise already direct.
- `coop_manager.gd`: only our additions/modified sections were considered, not the inherited ~15k-line implementation. Details below.

## Manager areas

- Admission/identity: challenge scope and nonce rejection are separate checks; occupied player keys have a clear local name. Compatibility guards, transport-bound identity, challenge/claim/grant persistence and rejection codes unchanged.
- Runtime leases: `locally_owned` describes the actual process/disabled gate. Sender validation separates admission, epoch/freeze, activity and instance checks. Plain comments mark final old-owner save and install-before-resume phases. All freeze/ACK/timeouts/CAS machinery retained because it enforces required behavior.
- Canonical terrain/checkpoints: removed unused player-state samples from our local checkpoint filter and unused locals in checkpoint reply; filtering still uses latched chunk owners, current revisions and the same durable publish/apply/ACK order. Region validation, bounded batches and fail-closed terrain installation remain intact.
- Private worlds/respawn maps: split install/current-epoch/private-instance/map validation and live-publication readiness into separate guards. Covered merge, absent-vs-empty, legacy proof and root-qualified paths unchanged. Migration arguments are named save_data, target_namespace and can_adopt_plain_save instead of a long inline expression.
- Travel/visits: reviewed our checkpoint-before-transfer and host snapshot path. Kept queued destination ownership and asynchronous travel because the base loader consumes it after saving the outgoing world. Existing short owner/key parsing, request and positioning methods were left alone; further extraction would add indirection.
- Profiles/reconnect: split host profile readiness/recovery guards; named previous_revision and made acknowledgement success explicit. Inventory application, revision advance, authoritative recovery and travel checkpoint waits preserved.
- Durable pickup/objects: expanded the Drop record literal so item/inventory and motion fields are visible. Same field order and values, no native serialization calls. Retained capture/materialize/replacement/UUID/receipt routines because each separates a distinct side effect, and their current flow is direct.
- Chest/death/pickup: prior pass already made transaction validation and field names clearer. This pass reviewed the manager-owned pending lock, ACK-before-release, queued receipts, timeout/reconnect, offline close and sender validation; kept these useful guards and boundaries. No extra transaction abstraction added.
- Combat RPCs/hooks: reviewed our target-UUID/epoch guards and damage forwarding. They are already direct rejection/forwarding code, so kept intact.

## World and native-facing overrides

Changed:
- `main/world/world.gd`: private map load now uses an explicit manager/fallback branch instead of a long ternary. Plain comments explain retained old data and proven source ownership. Public/ownerless typed restoration and existing private-load rollback retained.
- `main/save_file/preserve_node_manager.gd`: the typed map local is `restored_chunks`, not `empty` after it has been filled.
- `main/entity/entity.gd`: named water-level and neighbor-position units; separate unloaded-neighbor guard; plain explanation of pending death loot before a handoff. Same calculation and death ordering.
- `main/autoload/ref.gd`: plain explanation of the exact-DLL validation gate.

Our changed sections left unchanged because already simple:
- `behaviors/attack/attack.gd`: one lease guard and explicit three-argument damage call.
- `behaviors/drop_items/drop_items.gd`: two direct mutation guards before inventory/spawn side effects.
- `behaviors/pick_up_items/pick_up_items.gd`: one durable interception before native acceptance.
- `bubblebear/bubblebear.gd`: the small ANGRY compatibility branch directly chooses chase or IDLE.
- `gel/gel.gd`: small mini/major index choice, direct lease guards, damage forwarding and body repositioning; original softbody setup retained.
- `held_heart_thrower/heart/heart.gd`: one additional damage-position argument.
- `living_block/cache_cube/cache_cube.gd`: short designation/interact/break hooks; do not cache repeated designation lookups because breaking can change that state.

## Scripts and tests

Changed:
- `scripts/test_local_coop.ps1`: named pack argument list and captured stdout/stderr tasks; separate completion/result validation from exit/error checks. Same mandatory artifact, isolated profiles, process handles, deadlines, atomic markers and strict gates.
- `tests/local_coop.gd`: `_run` now shows startup, chosen role and shared shutdown. Host and guest flows each have a straight named function returning success, reducing nesting. Removed unused start-time field; wait time is named deadline. No LAN launch or native retry.
- `scripts/build_raw_mod.ps1`: now parses the retained local-coop fixture under the actual original-pack runtime without executing it, so the role refactor receives compile coverage despite the exhausted gameplay branch. Emits `COOP_LOCAL_COOP_FIXTURE_PARSE_OK`; existing strict fail-fast remains.
- `tests/chunk_authority.gd`: four channel/seed assertions added; all original assertions retained.

Reviewed and retained:
- `scripts/build_mod.ps1`: straightforward raw/export dispatch plus disposable staging and checked cleanup; no useful simplification without obscuring safety.
- `scripts/mod_files.ps1`: short shared path/PCK/hash/atomic/install-manifest checks are useful reusable boundaries.
- `scripts/install_mod.ps1`, `uninstall_mod.ps1`: explicit backup, publish, rollback and cleanup order is easier to audit than a generic transaction wrapper; preserve tested safety paths.
- `tests/admission.gd`: scenario and per-peer setup mirrors actual auth lifetimes; retain real wire branches and validation cases.
- `tests/region_checkpoint.gd`, `region_runtime.gd`, `canonical_runtime.gd`: retain direct test setup, actual region/load/application seams and explicit failure assertions; no generic fixture framework.
- `tests/personal_store.gd`, `private_respawns.gd`, `runtime_lease.gd`: existing sequential data/conservation/corruption/write-failure assertions are already straightforward. Their fake writers are essential failure injection, not removable flexibility.
- `tests/instance_entities.gd`, `lease_runtime.gd`, `profile_runtime.gd`, `respawn_runtime.gd`: keep explicit live-reference restoration, transport scopes and isolated test doubles; merging these would hide which actual method is exercised. No assertion removed or softened.
- `tests/combat.gd`, `native_collision.gd`, `native_guard.gd`: retain real native/render predicates, bounded controls and resource ownership; the native crash branch is not reopened.
- `tests/startup_diagnostic.gd`, `startup_diagnostic_check.gd`: direct observer/marker checks already simple.
- `tests/test_build_switches.ps1`, `test_install.ps1`, `test_native_timeout.ps1`, `test_shader_deadline.ps1`: preserve explicit setup/error/exit/deadline cases and cleanup; all parse checked. No installer/timeout behavior changed.

## Verification so far

- Pinned 4.6 double isolated actual chunk module/test: `CHUNK_AUTHORITY_RESULT 17 checks 0 failures`, exit0, empty stderr. Logs `work/readability-probe/stdout.txt`, `stderr.txt`, `godot.log`.
- All PowerShell scripts/tests parse: `ALL_POWERSHELL_PARSERS_OK`.
- Existing build-switch guard: `BUILD_SWITCH_CHECKS_OK 3`.
- Scoped `git diff --check` passes (line-ending warnings only).
- Root strict run3d21aab9ba904f2d833f37257430def1 PASS383assertions0failures+67 production scripts and `COOP_LOCAL_COOP_FIXTURE_PARSE_OK`. Steam0/noERROR. Independent review found no significant issues. First broad attempt passed, no repairs used. No two-process launch or native crash retry in this pass.
