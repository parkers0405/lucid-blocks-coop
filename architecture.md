# Lucid Blocks co-op architecture

Status: mod-only implementation for review, 2026-11-10. Local contract tests cover identity, persistence, private-instance saved entities and authority handoffs; complete live gameplay remains unverified. `tasks.md` is the execution ledger. Preserve the base game; real-player and human-input tests are deferred under the current review scope.

## Runtime and hard boundaries

Target Steam app3495730/build26206996, game5.2.0.0, Windows x86-64, Godot4.6 double, GodotSteam4.17.1. Current and historical fingerprints: `authorization.md`; engine guide: `../guide.md`. Generic PATH Godot is not the matching runtime.

- Purchased install, original native libraries/executable and personal saves stay unchanged. Stage original runtime material privately under ignored `work/` with isolated profiles. No install, push, release, driver change or native rebuild belongs to this scope.
- Existing `main/autoload/ref.gd` creates one manager; production retains one active `Ref.world` per process. Two native Worlds in a fixture are a test arrangement, not production architecture.
- Native hook/multi-region proposals and `native_patch/` are historical reference only. No replacement DLL, RVA patch or native-union capability is required. Keep unsupported-native guards fail closed; do not enable historical native deployment.
- Recovered assets/scripts are private reference. Single-precision recovery does not reproduce original double-precision resources; never package/commit commercial recovered material.
- One source writer owns each task, callers and fixtures. Architecture work edits only this file; no source, project file or engine configuration edits. Preserve unrelated `.import` changes.
- `scripts/build_raw_mod.ps1` owns isolated staging, packed checks and local output publication. `install_mod.ps1`/`uninstall_mod.ps1` own separately authorized deployment/rollback. Avoid inherited combined build/deploy scripts.

## Systems and state owners

Production paths below are relative to `mod/overrides/`.

| System | Single owner | State and collaborators |
|---|---|---|
| Bootstrap | `main/autoload/ref.gd` | Scene references, one manager, guarded native capability loading. |
| Session orchestration | `coop_mod/coop_manager.gd` | Transport, nonce/grant admission, sender identity map, reconnect, terrain epoch, snapshots, travel barriers, chest interaction sessions. |
| Durable identities | `coop_mod/session_identity.gd` | Random LAN identity/token; host token-digest mapping; bounded record reads and verified replacement. Steam key uses transport-derived ID. |
| Personal ledger | `coop_mod/personal_store.gd` | One shared binary ledger containing player profiles,21chest slots, revisions/receipts and full-instance UUID records/owners/tombstones; atomic inventory/object checkpoints and inventory/chest transfers. |
| Canonical chunks | `coop_mod/chunk_authority.gd` | Owner selection, channel fingerprints/revisions, stale-version checks and16-chunk batches. Manager authenticates/persists accepted updates. |
| Local world | `main/world/world.gd` | Local player-centered native loading, predictive dynamics, checkpoint filtering, active generator/dimension/private namespace. |
| Region storage | `coop_mod/region_checkpoint.gd` | Block/water/awake/fire validation, coordinates/IDs, immutable payload generations, checksums, manifest replacement and retained migration sources. |
| Personal chest UI | `coop_mod/personal_chest.gd` |21slots, explicit Store/Take quantity actions, ordinary player/menu mutation disabled during interaction, acknowledged inventory application. |
| Access blocks | `main/world/living_block/cache_cube/cache_cube.gd` | Ordinary cube behavior; designation routes to personal UI, independent of contents. |
| Preserved nodes/entities | `main/save_file/preserve_node_manager.gd`, existing entity overrides | Game node serialization/materialization; manager owns instance and authority routing. Private namespace/live handoff integration remains unfinished. |

Reuse existing helpers; do not introduce a parallel store, alternate inventory engine or unrelated manager refactor.

## Identity, reconnect and trust

Compatibility precedes identity admission. Manager owns nonce challenge, host/save-scoped identity namespace, grant acknowledgement and admitted sender-to-key map. `session_identity.admit` issues an opaque LAN credential for a new identity, persists its digest mapping, rejects occupied identities and invalid records. Client credentials remain scoped to host identity namespace. Names, peer numbers, IP addresses and caller player keys are not authentication.

Steam identity comes from the actual transport mapping, never client claims or lobby metadata. Missing/unsupported mapping fails admission. An injected test adapter proves routing/fail-closed behavior, not production Steam authentication. Two authenticated accounts are unavailable, so real Steam invite/reconnect evidence is outstanding.

Mutating profile RPCs check identity against admitted sender. Host durable revision acknowledges profile state; reconnect restores host state before mutation. Stale profiles must not overwrite newer inventory/chest commits. Freeze a disconnected guest's host-world progression during reconnect, rather than promoting it to offline authority. Reject old terrain epochs after reconnect.

LAN bearer credentials are trusted-network co-op, not encrypted protection against an observer. Delegated simulation cannot provide hostile-client anti-cheat. Validate sender, instance, epoch/revision, bounded payload/coordinates, item ID/count/stack and reach on host. Never decode executable Objects or network-selected scene paths. Ambiguous legacy identity records remain preserved rather than assigned by display name.

## Independent residency and canonical terrain

Each process loads a normal local bubble using original native `set_loaded_region_center` around its own player. No alternating centers, huge spanning host radius, tether or native union.

Original native `simulate_dynamic()` uses fixed64-unit radius around `center_chunk` (`work/gdblocks-source/extension/src/world.cpp` and `extension/include/world.h`); no per-chunk simulation filter is exposed. Local dynamics are predictions. A script ownership rule cannot make overlapping native simulation exclusive.

Current `chunk_authority.owner` favors host within128units in the same instance, otherwise active guest within144units, otherwise host. Manager filters local checkpoint chunks by canonical owner. Revisions/fingerprints cover block, water, water-awake and fire channels. Guest commits validate admitted instance membership, terrain epoch, expected revisions, canonical owner and16-chunk cap before region persistence. Advance revisions/acknowledge only after successful commit. Reject stale writes and supply canonical rebase.

Current canonical tick is2seconds: host captures changed owned chunks; guest checkpoints owned chunks. Canonical application queues/merges pending updates while busy. `_apply_canonical_terrain` pauses dynamics, waits for loading under5second deadline, rechecks world/instance/epoch and applies original region/block APIs. Restore processing safely on cancellation. Overlap predictions can visibly diverge until reconciliation; this is not lockstep.

Remaining live handoff contract: freeze affected authoritative mutation, commit final old-owner revision, publish/rebase new owner, then resume. Preserve queued work across acknowledgement failure; delayed former-owner writes cannot overwrite new state. Owner-function/revision fixtures do not prove moving handoff. Test separation, approach and reunion with edits/water/fire and entities.

## Dimensions, Apotheosis and saved nodes

Each process retains one active dimension. Public keys identify dimension; personal POCKET/FIRMAMENT keys include stable owner identity. Visiting another Apotheosis keeps the owner's world namespace and visitor's own profile/chest. Authorization comes from admitted visit occupancy, not visitor-key equality with world owner.

Reuse manager `_open_dimension_instance_async`, `_await_local_world_checkpoint`, `_await_guest_world_patch_flush_for_instance`, `_queue_loaded_dimension_instance`, world `queue_dimension_instance` and region migration/load. Durably checkpoint source before teleport; obtain target host checkpoint without forcing the other player to travel. Failed barriers cancel transition and preserve recoverable state. Reconnect restores saved player instance/position rather than automatically following host.

Travel callers to audit/finish: `main/world/living_block/portal_block/portal_block.gd`, `main/entity/hamsa/hamsa.gd`, `main/world/living_block/cutscene_block/cutscene_block.gd`, `main/plot/plot_manager.gd`, `main/entity/player/player.gd`, plus manager commands/visit UI. Historical group helper presence does not establish independent travel. Preserve solo behavior and define initiator/instance ownership for story transitions.

Terrain files do not cover preserved entities, living blocks, cache inventories, drops and all respawn state. Scope saved-node dictionaries/chunk-to-UUID maps by full instance key; prevent UUID materialization/tombstones crossing private namespaces. Manager integration points: `_get_saved_chunk_to_uuid_map`, `_store_saved_chunk_to_uuid_map`, `_materialize_entity_from_save_bundle`, `_store_guest_authoritative_entities`, `_send_local_authoritative_entities_to_host`. One authority owns each entity UUID; transfer its final state/epoch before resuming elsewhere. Cover overlap, visitor arrival/departure, death/disconnect and restart. **Entity/private-instance saved-node handling and live authority handoff remain unfinished/unverified.**

## Persistence and chest

Host is final disk authority. Regions have immutable generations/manifests. `personal_store` uses one shared binary profile/chest/object ledger through verified same-volume replacement; `_profile_path` derives identity paths under host co-op sidecar. Profile/chest/revision/receipts commit together. Profiles, chest contents and preserved-object removals share one atomic generation. Terrain regions remain a separate checkpoint unit; do not claim a single disk transaction across terrain and the ledger.

Host `/enderchest` designates an existing empty standard cache cube; no cabinet/hopper, recipe or art. Designations are keyed by instance/block coordinate; contents by host save/player identity. Contents survive access-block destruction. Block `%Inventory`, ordinary storage broadcasts, drops/hoppers and visitor profiles must never expose the personal ledger.

Dedicated UI avoids native drag/cursor mutation paths. It shows21slots and explicit Store/Take quantity operations between Inventory/Hotbar and chest. Host interaction token binds admitted player, instance, access block and reach. `personal_store.transfer` validates revision, source/count, stack compatibility including durability/position and capacity, commits both sides plus receipt, then returns acknowledged state. Disable ordinary player/menu mutation during session. Invalidate on death, travel, disconnect, block destruction or leaving reach. Last32duplicate request IDs return committed state; older replay must fail stale revision rather than apply again.

Remaining barriers cover ordinary guest profile writes racing chest commits, host close/restart, disk failure and preserved-node changes. No durable write means no success acknowledgement. Retain previous valid state and failed migration sources. Backup/restore consistency among vanilla data, regions, identities/designations and personal ledgers requires explicit checks; clean save/reload alone does not prove crash durability.

## Evidence and remaining verification

Strict combined run `work/build-logs/33c9c4ab9c854c6096683443b229df96/`: region28/runtime45, admission73, native guard4, personal store17, chunk authority13, profile runtime16, canonical runtime9 and startup66, all zero failures. Stdout ends `COOP_BUILD_CHECK_OK 66`; stderr retains the deliberate failed-load warning and ObjectDB exit warning. Strict runner accepted the run. These prove named local contracts, not production two-player play. Earlier55combat assertions/two original Gel renders are separate evidence. Inherited rendered shutdown errors reproduce without co-op and do not authorize base-game/native repairs.

Exact existing combined command from project root:

```powershell
& ./scripts/build_raw_mod.ps1 -Godot ./work/tools/godot.windows.editor.double.x86_64.exe -Gdre ./work/tools/gdre-2.7.4/gdre_tools.exe -GameExe 'C:/Program Files (x86)/Steam/steamapps/common/lucid-blocks/lucid-blocks.exe' -ProjectDir ./mod/overrides -OutputDir ./work/mod-only-verification-output -RegionTests -AdmissionTests
```

Uses original native files, never `-NativeBaseline`. Runner freezes fixture input in staging, checks scripts and explicit markers/errors/exit/deadlines, isolates profiles and owns process cleanup. Reuse unchanged evidence. Expand fixtures for changed behavior, run costly checks sequentially; missing gameplay/transport execution remains unverified, never passed.

| Order | One-writer files | Existing exact hook and required assertions |
|---|---|---|
|1 Saved nodes/private instances | Manager, preserve-node override, implicated entity/living-block callers; `tests/region_runtime.gd`, `tests/profile_runtime.gd` | Combined command above: identical coordinates in two owner instances; UUID isolation, visitor mutation, tombstones, restart and ordinary cache regression. |
|2 Live authority handoff | Manager, chunk owner, world, implicated entity callers; `tests/chunk_authority.gd`, `tests/canonical_runtime.gd` | Same command: final checkpoint before new owner, old packet rejected, edits/water/fire converge, interrupted handoff preserves durable state; live path still requires retained scenario. |
|3 Independent travel/reconnect | Manager and exact portal/Hamsa/cutscene/plot/player callers listed above; admission/profile/region fixtures | Same command: initiator-only travel, both private visits persist, reconnect restores identity/position/instance, stale profile cannot overwrite chest. |
|4 Chest lifecycle/failures | Personal store/UI, manager, cache cube; personal-store/profile fixtures | Same command: conservation, full stacks/inventory, duplicate/reordered transfer, write failure, close/death/break/reconnect, private visibility and ordinary cubes. |
|5 Local integration | Only failed-feature owners above and runtime fixtures | Same command plus retained isolated two-process gameplay scenario: distant movement/build/combat, dimensions/visits/chest, save/rejoin, original native hashes unchanged. Unimplemented live scenario is remaining work, not an executable claim. |

Stop after requested mod work and truthful local verification report. Real two-account Steam invite/reconnect and multiplayer soak remain unavailable external evidence; do not expand into base-game shutdown cleanup/native development.

## Risks and exclusions

Remaining risks: live entity/terrain handoff; private saved-node leakage; overlap prediction correction; lifecycle transaction races; backup/restore consistency; unbounded immutable region generation growth. Retention cleanup needs proven live-manifest ownership before deleting only mod generations; never remove base/personal saves. Two original native Worlds in a fixture do not prove networked production streaming.

Excluded: native/base-game modifications, dedicated server, >2players, host migration, new art/avatars/recipes, general multiworld scene rewrite, hopper-to-personal-storage automation, hostile-client anti-cheat and unrelated refactors. Architecture or fixture counts alone do not justify an installable/co-op-complete claim.

## 2026-10-26 verified storage/target checkpoint and active corrections
Strict c1b7ee985c8044c8b4a4ba406bad6fd2 against original5.2pack/unchangedworldDLL:228assertions0failures+67scripts, tooling3guards pass. Storagecommitc0c83dd. Shared ledger covers atomic pickupfailure/success, perUUIDCAS/tombstones, privateisolation, unloadedcapture andcorruptionrefusal. PeriodicentityRPC isruntimeonly; profileRPC carriesfullobjects; guesttravelwaitsprofileACK. Currentreviewidentified remainingP1s: prematurepositionbasedownerCAS, coarseentitysplitbrain/dropdeletion, terrainboundaryunsenteditloss, missingprivatelegacyadoption, chestACK/UIlifetime/pickupreceiptrace. Solewriter firstcorrects private/chest, then latchedleasefreeze/finalcheckpoint/installACK. Each requires retained regression and original-native verification before completionclaim. Wholelocalruntimebrieflyfrozen duringhandoff is acceptable minimal implementation; indefinitefailure must notgrantbothowners.

## Verified lifecycle checkpoint11b6bc5 and active lease sequence
Strict1509ba30 passed239 assertions and67 scripts with original5.2 native binaries. Manager-owned chest transaction lifetime now outlives panel lifetime; timeout recovers authoritative profile while inventory remains locked. Private loading validates prior sourceowner before switching, retaining proven legacy source nodes and refusing ambiguous source mutation. Exact durable pickup receipts and live authority remain nextphase.

The implementation sequence for moving leases is: latch current per-chunk and UUID owner; compute proposed assignment from pre-freeze admitted state; freeze mutation on both peers; allow explicit old-epoch profile/object and terrain barrier writes; persist ownership CAS and increment lease epoch; install canonical active-instance terrain and exact UUID bundles; await installation acknowledgement; resume only committed owners. Pre-commit failure retains old lease. Post-commit missing acknowledgement stays frozen and reconnects. Gate profile snapshots during installation so absent newlyassigned nodes cannot be tombstoned. Runtime processing, damage, pickup, periodic bundles and deletion must consult the same lease. Freeze-induced inactive player state cannot recompute ownership or block final barrier writes.

## Final run checkpoint2026-10-27 (user requested stop)
Strict632f5b14e0c642db9fe424ba02a796e1 passed311assertions+67scripts after two lease repairs. Mod-owned drop serializers avoid temporary InventoryNodes while preserving native item/motion format. Runtime ownership, atomic pickup, exactUUID replacement, controlled-lock presence and canonical disconnect reclamation have retained helper/native evidence. Actual two-process gameplay and private respawn metadata remain unfinished. Stop after final local commit per user instruction; no native/base/install/outward actions.
