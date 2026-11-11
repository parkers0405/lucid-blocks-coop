# Lucid Blocks co-op architecture

Status: gameplay responsiveness update, 2026-11-10. Local contracts and automated LAN gameplay are the evidence; current results and external Steam/human-test limits are in `playtest.md`. `tasks.md` is the execution ledger.

## Runtime and hard boundaries

Target Steam app3495730/build26206996, game5.2.0.0, Windows x86-64, Godot4.6 double, GodotSteam4.17.1. Current and historical fingerprints: `authorization.md`; engine guide: `../guide.md`. Generic PATH Godot is not the matching runtime.

- Purchased install, original native libraries/executable and personal saves stay unchanged. Stage original runtime material privately under ignored `work/` with isolated profiles. No installation, release, driver change or native rebuild belongs to this scope. Feature-branch pushes to the fork are allowed.
- Existing `main/autoload/ref.gd` creates one manager; production retains one active `Ref.world` per process. Canonical fixtures use one native World; independent loading is checked in separate host and guest processes.
- Native hook/multi-region proposals and `native_patch/` are historical reference only. No replacement DLL, RVA patch or native-union capability is required. Keep unsupported-native guards fail closed; do not enable historical native deployment.
- Recovered assets/scripts are private reference. Single-precision recovery does not reproduce original double-precision resources; never package/commit commercial recovered material.
- One source writer owns each task, callers and fixtures. Architecture work edits only this file; no source, project file or engine configuration edits. Preserve unrelated `.import` changes.
- `scripts/build_mod.ps1` owns isolated staging, packed checks and local output publication. `install_mod.ps1`/`uninstall_mod.ps1` own separately authorized deployment/rollback. Avoid inherited combined build/deploy scripts.

## Systems and state owners

Production paths below are relative to `mod/overrides/`.

| System | Single owner | State and collaborators |
|---|---|---|
| Bootstrap | `main/autoload/ref.gd` | Scene references, one manager, guarded native capability loading. |
| Session orchestration | `coop_mod/coop_manager.gd` | Transport, nonce/grant admission, sender identity map, reconnect, terrain epoch, snapshots, travel barriers, chest interaction sessions. |
| Durable identities | `coop_mod/session_identity.gd` | Random LAN identity/token; host token-digest mapping; bounded record reads and verified replacement. Steam key uses transport-derived ID. |
| File execution | `coop_mod/save_queue.gd` | Built-in WorkerThreadPool executes immutable pure file operations; durable transactions precede queued routine work, preserving durable FIFO. Started jobs return results even after disconnect for same-save reconciliation; obsolete queued session work is logged and discarded, while queued local checkpoints are retained. No external worker/service/configuration. |
| Personal ledger | `coop_mod/personal_store.gd` | One shared binary ledger containing player profiles,21chest slots, revisions/receipts and full-instance UUID records/owners/tombstones; atomic inventory/object checkpoints and inventory/chest transfers. |
| Canonical chunks | `coop_mod/chunk_authority.gd` | Owner selection, channel fingerprints/revisions, stale-version checks and16-chunk batches. Manager authenticates/persists accepted updates. |
| Local world | `main/world/world.gd` | Local player-centered native loading, predictive dynamics, checkpoint filtering, active generator/dimension/private namespace. |
| Region storage | `coop_mod/region_checkpoint.gd` | Block/water/awake/fire validation, coordinates/IDs, immutable payload generations, checksums, manifest replacement and retained migration sources. |
| Personal chest UI | `coop_mod/personal_chest.gd` |21slots, explicit Store/Take quantity actions; modal inventory protection is separate from pickup protection. Pickups retain movement, mining, attacks and hotbar selection; conflicting drop/item-use inputs defer until ACK. Sparse inventory application preserves concurrent tool wear and broken tools. |
| Access blocks | `main/world/living_block/cache_cube/cache_cube.gd` | Ordinary cube behavior; designation routes to personal UI, independent of contents. |
| Preserved nodes/entities | `main/save_file/preserve_node_manager.gd`, existing entity overrides | Game node serialization/materialization; manager owns instance and authority routing. Canonical handoff includes offscreen owned bundles before snapshots resume. |

Reuse existing helpers; do not introduce a parallel store, alternate inventory engine or unrelated manager refactor.

Routine personal checkpoints run every5seconds. Unchanged-ledger comparison uses dictionary equality rather than reserializing the ledger. Active snapshot, rebase, migration and respawn-adoption reads use the file queue; handoffs request only needed chunks from the region worker. Synchronous engine loading callbacks drain the queue before direct metadata reads. Those loading-only reads and small chest-access JSON reads remain main-thread IO; this is not a universal zero-IO claim.

## Identity, reconnect and trust

Compatibility precedes identity admission. Manager owns nonce challenge, host/save-scoped identity namespace, grant acknowledgement and admitted sender-to-key map. `session_identity.admit` issues an opaque LAN credential for a new identity, persists its digest mapping, rejects occupied identities and invalid records. Client credentials remain scoped to host identity namespace. Names, peer numbers, IP addresses and caller player keys are not authentication.

Steam identity comes from the actual transport mapping, never client claims or lobby metadata. Missing/unsupported mapping fails admission. An injected test adapter proves routing/fail-closed behavior, not production Steam authentication. Two authenticated accounts are unavailable, so real Steam invite/reconnect evidence is outstanding.

Mutating profile RPCs check identity against admitted sender. Host durable revision acknowledges profile state; reconnect restores host state before mutation. Stale profiles must not overwrite newer inventory/chest commits. Freeze a disconnected guest's host-world progression during reconnect, rather than promoting it to offline authority. Reject old terrain epochs after reconnect.

LAN bearer credentials are trusted-network co-op, not encrypted protection against an observer. Delegated simulation cannot provide hostile-client anti-cheat. Validate sender, instance, epoch/revision, bounded payload/coordinates, item ID/count/stack and reach on host. Never decode executable Objects or network-selected scene paths. Ambiguous legacy identity records remain preserved rather than assigned by display name.

## Independent residency and canonical terrain

Each process loads a normal local bubble using original native `set_loaded_region_center` around its own player. No alternating centers, huge spanning host radius, tether or native union.

Original native `simulate_dynamic()` uses fixed64-unit radius around `center_chunk` (`work/gdblocks-source/extension/src/world.cpp` and `extension/include/world.h`); no per-chunk simulation filter is exposed. Local dynamics are predictions. A script ownership rule cannot make overlapping native simulation exclusive.

Current `chunk_authority.owner` favors host within128units in the same instance, otherwise active guest within144units, otherwise host. Manager filters local checkpoint chunks by canonical owner. Revisions/fingerprints cover block, water, water-awake and fire channels. Guest commits validate admitted instance membership, terrain epoch, expected revisions, canonical owner and16-chunk cap before region persistence. Advance revisions/acknowledge only after successful commit. Reject stale writes and supply canonical rebase.

Current canonical tick is2seconds: host captures changed owned chunks; guest checkpoints owned chunks. Canonical application queues/merges pending updates while busy. `_apply_canonical_terrain` waits for loading under5second deadline, rechecks world/instance/epoch and applies original region/block APIs in bounded slices. Dynamics continue between slices. Routine capture skips loading/restoration; explicit checkpoint barriers leave native loading enabled until it settles, with bounded waits and context checks. Overlap predictions can visibly diverge until reconciliation; this is not lockstep.

Live handoff contract: freeze affected authoritative mutation, commit final old-owner revision, publish/rebase new owner, then resume. Preserve queued work across acknowledgement failure; delayed former-owner writes cannot overwrite new state. Focused runtime regressions cover commit interruption, stale installers and object recovery; the two-process scenario checks independent exploration and terrain persistence. Human reunion playfeel remains unmeasured.

Do not start a handoff while terrain is streaming. If streaming restarts during awaited handoff work, abort and resume rather than waiting15seconds while frozen. Durable checkpoints reserve their turn before draining an existing background checkpoint, preventing routine work from repeatedly taking the barrier slot. A background save does not own the player-lock restoration state.

## Dimensions, Apotheosis and saved nodes

Each process retains one active dimension. Public keys identify dimension; personal POCKET/FIRMAMENT keys include stable owner identity. Visiting another Apotheosis keeps the owner's world namespace and visitor's own profile/chest. Authorization comes from admitted visit occupancy, not visitor-key equality with world owner.

Reuse manager `_open_dimension_instance_async`, `_await_local_world_checkpoint`, `_await_guest_world_patch_flush_for_instance`, `_queue_loaded_dimension_instance`, world `queue_dimension_instance` and region migration/load. Durably checkpoint source before teleport; obtain target host checkpoint without forcing the other player to travel. Failed barriers cancel transition and preserve recoverable state. Reconnect restores saved player instance/position rather than automatically following host.

Travel callers: `main/world/living_block/portal_block/portal_block.gd`, `main/entity/hamsa/hamsa.gd`, `main/world/living_block/cutscene_block/cutscene_block.gd`, `main/plot/plot_manager.gd`, `main/entity/player/player.gd`, plus manager commands/visit UI. Travel retains source checkpoint barriers and instance ownership. Automated independent travel and following exercise the ordinary dimension path; every story transition is not individually playtested.

Terrain files do not cover preserved entities, living blocks, cache inventories, drops and all respawn state. Scope saved-node dictionaries/chunk-to-UUID maps by full instance key; prevent UUID materialization/tombstones crossing private namespaces. Manager integration points: `_get_saved_chunk_to_uuid_map`, `_store_saved_chunk_to_uuid_map`, `_materialize_entity_from_save_bundle`, `_store_guest_authoritative_entities`, `_send_local_authoritative_entities_to_host`. One authority owns each entity UUID; transfer its final state/epoch before resuming elsewhere. Cover overlap, visitor arrival/departure, death/disconnect and restart. Runtime regressions cover private namespaces, preserved objects and interrupted ownership commits; exhaustive live entity combinations remain outside local coverage.

## Persistence and chest

Host is final disk authority. Regions have immutable generations/manifests. `personal_store` uses one shared binary profile/chest/object ledger through verified same-volume replacement; `_profile_path` derives identity paths under host co-op sidecar. Profile/chest/revision/receipts commit together. Profiles, chest contents and preserved-object removals share one atomic generation. Terrain regions remain a separate checkpoint unit; do not claim a single disk transaction across terrain and the ledger.

Host `/enderchest` designates an existing empty standard cache cube; no cabinet/hopper, recipe or art. Designations are keyed by instance/block coordinate; contents by host save/player identity. Contents survive access-block destruction. Block `%Inventory`, ordinary storage broadcasts, drops/hoppers and visitor profiles must never expose the personal ledger.

Dedicated UI avoids native drag/cursor mutation paths. It shows21slots and explicit Store/Take quantity operations between Inventory/Hotbar and chest. Host interaction token binds admitted player, instance, access block and reach. `personal_store.transfer` validates revision, source/count, stack compatibility including durability/position and capacity, commits both sides plus receipt, then returns acknowledged state. Block inventory mutation during the session. Pending Close/Escape releases movement immediately; the inventory lock remains until the transaction result. Unchanged slots keep their existing held/equipped instances. Invalidate on death, travel, disconnect, block destruction or leaving reach. Last32duplicate request IDs return committed state; older replay must fail stale revision rather than apply again.

Durable barriers cover ordinary guest profile writes racing chest commits, host close/restart, disk failure and preserved-node changes. No durable write means no success acknowledgement. Retain previous valid state and failed migration sources. Backup/restore consistency among vanilla data, regions, identities/designations and personal ledgers requires explicit checks; clean save/reload alone does not prove crash durability.

## Verification for a solo maintainer

Routine verification is `scripts/build_mod.ps1` with matching `-Godot`, `-Gdre`, `-GameExe` paths and `-Test`, then `tests/test_install.ps1`. The single builder packages mod resources, loads scripts against the original runtime, and runs focused identity, region, inventory/chest, private-node, canonical-terrain, lease and respawn regressions. The installer suite uses synthetic directories and verifies rollback and preservation of existing files. Neither command installs into the owned game.

Use `-CombatTests` separately after combat/render changes; preserve its original assets, renderer, deadlines and explicit result/error gates. Other changes do not need rendered controls, native rebuilds, diagnostic self-tests or a one-hour soak by default. The removed native/startup/world-process diagnostic harnesses remain in Git history; their historical logs do not become passing gameplay evidence.

Validation, atomic persistence, revision/receipt guards, owner checks and fail-closed native capability gating remain production requirements. Tests of the same helper through several alternate APIs are unnecessary; fixtures use the actual checkpoint and lease APIs. Run the routine checks once after the relevant changes; repeat only for new failures or changed inputs.

Automated LAN checks exercise real input, independent ownership, canonical terrain persistence and reconnect. Current dated results are in playtest.md. The expanded headless launcher retains strict failures from offline Steam and native shutdown resources. Real two-account Steam invites and subjective playfeel remain outside local coverage.

## Risks and exclusions

Remaining risks: live entity/terrain handoff; private saved-node leakage; overlap prediction correction; lifecycle transaction races; backup/restore consistency; unbounded immutable region generation growth. Retention cleanup needs proven live-manifest ownership before deleting only mod generations; never remove base/personal saves. Independent streaming evidence comes from separate host and guest processes, with one native World each.

Excluded: native/base-game modifications, dedicated server, >2players, host migration, new art/avatars/recipes, general multiworld scene rewrite, hopper-to-personal-storage automation, hostile-client anti-cheat and unrelated refactors. Architecture or fixture counts alone do not justify an installable/co-op-complete claim.

## Gameplay responsiveness and recovery

Native generation receives a private fusion-table array to avoid shared packed-array detachment across chunk workers. Routine guest terrain saves skip active loading/restoration and capture a snapshot before waiting and leave movement/camera and world simulation running. The collecting peer records an accepted snapshot in its cache and revisions without replaying it over newer live cells. Explicit travel, quit and reconnect retain durable barriers. Canonical terrain applies in short slices with water before fire; pending changes are scoped by session epoch and dimension instance.

Pickups reserve inventory after any queued host save completes, conserve partial-stack remainders and serialize with chest transfers. An active glider defers automatic collection until gliding ends; ownership preparation preserves the glide. Passive equipment wear pauses during the durable inventory lock.

Leases use native loaded-position queries rather than dirty save-data as residency. Stable ownership and cached node modes avoid recursive per-frame work. Handoff freezes world mutations while retaining local movement/camera, commits the old owners' state, persists ownership, installs exact canonical terrain/objects and acknowledges before resuming. A pending-install marker distinguishes installed maps from installed objects. Disconnect recovery waits for queued IO, reconciles any committed epoch and object payload before a new checkpoint, then reclaims ownership. Every delayed installation checks its lease/session context; quit/travel waits for recovery.

A newly authenticated guest knows the session nonce; its first full snapshot may advance it to the host's current lease epoch within that same nonce. This covers reconnect and replacement guests. Ordinary runtime packets retain exact epoch checks. Protocol6 requires both peers to use the updated mod.
