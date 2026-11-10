extends Node
const DROP: String = "res://main/items/dropped_item/dropped_item.tscn"
const UUID: String = "33333333-3333-4333-8333-333333333333"
class Manager extends "res://coop_mod/coop_manager.gd":
    var fixture_root: String
    var live: bool = true
    func _ready() -> void:
        pass
    func _physics_process(_delta: float) -> void:
        pass
    func _has_live_peer() -> bool:
        return live
    func _can_sample_player() -> bool:
        return true
    func _can_share_loaded_world() -> bool:
        return true
    func _get_local_player_key() -> String:
        return "host"
    func _get_checkpoint_chunks_directory() -> String:
        return fixture_root.path_join("chunks")
    func get_active_dimension_instance_key() -> String:
        return "dimension:2"
    func _capture_local_state() -> Dictionary:
        return {"active": true, "dimension": 2, "dimension_instance_key": "dimension:2", "position": Vector3.ZERO}
    func _preserved_scene_paths() -> Dictionary:
        return {DROP: true}
    func _lease_ack_timeout_ms() -> int:
        return 0
    func _update_status_text() -> void:
        pass
class PresenceManager extends "res://coop_mod/coop_manager.gd":
    var fixture_root: String
    func _ready() -> void:
        pass
    func _physics_process(_delta: float) -> void:
        pass
    func _can_sample_player() -> bool:
        return true
    func _get_local_player_key() -> String:
        return "host"
    func _get_local_player_name() -> String:
        return "Presence fixture"
    func _get_checkpoint_chunks_directory() -> String:
        return fixture_root.path_join("chunks")
    func _update_status_text() -> void:
        pass
class CheckpointResumeManager extends Manager:
    func _drain_lease_mutations() -> bool:
        return false
class ReclaimManager extends Manager:
    var checkpoint_saw_old_barrier: bool = false
    var fail_apply: bool = false
    func get_active_dimension_instance_key() -> String:
        return "dimension:" + str(int(Ref.world.current_dimension))
    func _local_loaded_lease_chunks() -> Array:
        return [Vector3i.ZERO]
    func _checkpoint_local_host_world() -> bool:
        checkpoint_saw_old_barrier = lease_frozen and lease_checkpoint_allowed
        return true
    func _apply_canonical_terrain(_patch: Dictionary) -> bool:
        return not fail_apply
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("LEASE_RUNTIME_FAIL ", label)
func finish_loot_after_frame(node: Node) -> void:
    await get_tree().process_frame
    node.set_meta("coop_death_loot_pending", false)
func orphan_inventory_count() -> int:
    var count: int = 0
    for id in Node.get_orphan_node_ids():
        if instance_from_id(id) is Inventory:
            count += 1
    return count
func trace_orphan_inventories(stage: String) -> void:
    if not OS.get_cmdline_args().has("--verbose"):
        return
    var count: int = 0
    var script_path: String = ""
    for id in Node.get_orphan_node_ids():
        var node = instance_from_id(id)
        if node is Inventory:
            count += 1
            script_path = node.get_script().resource_path
    print("LEASE_ORPHAN_INVENTORY ", stage, " count=", count, " script=", script_path)
func run() -> int:
    trace_orphan_inventories("before_drop_fixture")
    var checkpoint_manager := CheckpointResumeManager.new()
    add_child(checkpoint_manager)
    var originally_disabled: bool = Ref.player.disabled
    for initially_disabled in [false, true]:
        checkpoint_manager.guest_checkpoint_busy = true
        checkpoint_manager.guest_checkpoint_was_disabled = initially_disabled
        Ref.player.disabled = true
        await checkpoint_manager._handoff_runtime_lease({})
        check(Ref.player.disabled, "lease cancellation preserves active checkpoint lock")
        checkpoint_manager.guest_checkpoint_busy = false
        checkpoint_manager._resume_lease_runtime()
        check(Ref.player.disabled == initially_disabled, "lease resume restores original state rather than temporary checkpoint lock")
    Ref.player.disabled = originally_disabled
    checkpoint_manager.free()
    var manager := Manager.new()
    manager.fixture_root = "user://lease_runtime_" + Crypto.new().generate_random_bytes(8).hex_encode()
    add_child(manager)
    var actor := Node3D.new()
    actor.set_meta("coop_uuid", UUID)
    add_child(actor)
    var key: String = manager.ChunkAuthority.chunk_key("dimension:2", Vector3i.ZERO)
    check(manager.chunk_authority.install_lease(1, {key: 2}, {"dimension:2|" + UUID: 2}), "runtime fixture installs granted guest owner")
    check(not manager.owns_runtime_node(actor) and not manager.can_mutate_runtime_node(actor), "host replica cannot process or mutate guest UUID")
    manager.peer_states[2] = {"active": true, "downed": false, "dimension_instance_key": "dimension:2"}
    manager.admitted_player_keys[2] = "guest"
    manager.terrain_epoch = "session:1"
    check(manager._valid_runtime_sender(2, "session:1") and not manager._valid_runtime_sender(2, "session:0"), "current epoch admitted sender passes and late epoch fails")
    manager.lease_frozen = true
    check(not manager._valid_runtime_sender(2, "session:1"), "frozen runtime rejects mutation RPC")
    var state: Dictionary = {"_coop_revision": 0, "node": {"player": {}}}
    check(manager._commit_player_checkpoint("host", state, "dimension:2", 2, []).is_empty(), "install phase cannot tombstone missing UUID via profile checkpoint")
    manager.lease_checkpoint_allowed = true
    check(manager._commit_player_checkpoint("host", state, "dimension:2", 2, []).get("revision") == 1, "explicit old-lease barrier checkpoint remains allowed while frozen")
    manager.lease_checkpoint_allowed = false
    manager.lease_token = "current_token"
    manager.lease_phase = "install_1"
    manager.lease_ack = {}
    manager._accept_runtime_lease_ack("current_token", "collect", "session:1", true)
    check(manager.lease_ack.is_empty(), "delayed freeze acknowledgement cannot satisfy install stage")
    manager._accept_runtime_lease_ack("current_token", "install_0", "session:1", true)
    manager._accept_runtime_lease_ack("current_token", "install_1", "session:0", true)
    check(manager.lease_ack.is_empty(), "wrong part and epoch acknowledgements rejected")
    check(not await manager._wait_lease_ack("current_token") and manager.lease_frozen, "lost install acknowledgement never resumes gameplay")
    manager._accept_runtime_lease_ack("current_token", "install_1", "session:1", true)
    check(await manager._wait_lease_ack("current_token"), "matching install acknowledgement completes wait")
    manager.lease_frozen = false
    manager.lease_preparing = false
    var prior_disabled: bool = Ref.player.disabled
    actor.set_meta("coop_death_loot_pending", true)
    manager.tracked_root_entities.append(actor)
    finish_loot_after_frame(actor)
    check(await manager._drain_lease_mutations() and not actor.get_meta("coop_death_loot_pending") and not manager.lease_frozen, "pending death loot drains before freezing awaited timers")
    manager.lease_preparing = false
    Ref.player.disabled = prior_disabled
    actor.free()
    manager.live = false
    var prior_file = Ref.save_file_manager.loaded_file
    Ref.save_file_manager.loaded_file = SaveFile.new()
    var drop = load(DROP).instantiate()
    drop.disabled = true
    get_tree().root.add_child(drop)
    var item := ItemState.new()
    item.id = 7
    item.count = 4
    item.set_position(Vector3i(4, 5, 6))
    drop.initialize(item, true)
    drop.movement_velocity = Vector3(1, 2, 3)
    drop.gravity_velocity = Vector3(0, -4, 0)
    drop.flow_velocity = Vector3(5, 0, 6)
    drop.target_flow_velocity = Vector3(7, 0, 8)
    manager._bind_sync_uuid(drop, UUID)
    var orphan_count_before: int = orphan_inventory_count()
    var bundle: Dictionary = manager._capture_entity_save_bundle(drop, UUID)
    check(orphan_inventory_count() == orphan_count_before, "drop capture allocates no orphan Inventory helper")
    var plain: String = SaveFile.DIMENSION_MAP[int(Ref.world.current_dimension)]
    var saved_drop: Dictionary = bundle["save_data"][plain]["node"][UUID]
    check(saved_drop[""]["capacity"] == 1 and saved_drop[""]["items"][1] == Vector3i(4, 5, 6) and saved_drop["global_position"] == drop.global_position and saved_drop["mv"] == drop.movement_velocity and saved_drop["gv"] == drop.gravity_velocity and saved_drop["fl"] == drop.flow_velocity and saved_drop["tfl"] == drop.target_flow_velocity, "drop record preserves native item position and all motion fields")
    trace_orphan_inventories("after_drop_capture")
    manager._merge_save_data_into_loaded_file(bundle["save_data"])
    drop.set_meta("coop_synced_drop", true)
    drop.can_collect = false
    drop.can_merge = false
    var replacement = manager._materialize_entity_from_save_bundle(bundle, true)
    check(orphan_inventory_count() == orphan_count_before, "drop restoration allocates no orphan Inventory helper")
    trace_orphan_inventories("after_drop_materialization")
    check(is_instance_valid(replacement) and replacement != drop and replacement is DroppedItem, "synced drop replaced with fresh native instance")
    check(manager._get_sync_uuid(replacement) == UUID and replacement.item.count == 4 and replacement.can_collect and replacement.can_merge, "exact UUID item count and native collection restored")
    check(replacement.item.get_position() == Vector3i(4, 5, 6) and replacement.movement_velocity == Vector3(1, 2, 3) and replacement.gravity_velocity == Vector3(0, -4, 0) and replacement.flow_velocity == Vector3(5, 0, 6) and replacement.target_flow_velocity == Vector3(7, 0, 8), "drop materialization restores item coordinates and every motion field")
    check(Ref.save_file_manager.loaded_file.get_data("node/" + UUID + "/file_path", "") == DROP, "protected old-node exit retains saved UUID record")
    replacement.disabled = true
    await get_tree().process_frame
    var mapped: int = 0
    for node in Ref.preserve_node_manager.node_to_uuid_map:
        if is_instance_valid(node) and Ref.preserve_node_manager.node_to_uuid_map[node] == UUID:
            mapped += 1
    check(mapped == 1 and Ref.save_file_manager.loaded_file.get_data("node/" + UUID + "/file_path", "") == DROP, "old deferred deletion cannot erase replacement or duplicate UUID")
    replacement.free()
    Ref.save_file_manager.loaded_file = prior_file
    manager.free()
    check_presence_capture()
    await check_disconnected_reclaim()
    trace_orphan_inventories("after_reclaim_fixture")
    print("LEASE_RUNTIME_RESULT ", checks, " checks ", failures, " failures")
    return failures

func check_presence_capture() -> void:
    var presence := PresenceManager.new()
    presence.fixture_root = "user://lease_presence_" + Crypto.new().generate_random_bytes(8).hex_encode()
    add_child(presence)
    var previous_disabled: bool = Ref.player.disabled
    var previous_dead: bool = Ref.player.dead
    var previous_blocked: bool = Ref.player.is_blocking_signals()
    var previous_file = Ref.save_file_manager.loaded_file
    Ref.save_file_manager.loaded_file = SaveFile.new()
    Ref.player.set_block_signals(true)
    Ref.player.dead = false
    Ref.player.disabled = false
    presence.begin_chest_inventory_lock()
    var state: Dictionary = presence._capture_local_state()
    check(state["active"] and presence._is_local_session_player_active() and not presence._is_local_session_player_targetable(), "real capture keeps chest-locked player present and untargetable")
    var instance: String = presence.get_active_dimension_instance_key()
    var dimension: int = int(Ref.world.current_dimension)
    var plain: String = SaveFile.DIMENSION_MAP[dimension]
    var position := Vector3i(Ref.player.global_position)
    var access: String = presence._chest_access_key(instance, position)
    Ref.save_file_manager.loaded_file.set_data("coop/chest_access", {access: true}, true)
    check(presence._valid_chest_session(1, instance, position), "real locked capture authorizes local chest access")
    var empty: Dictionary = {"node": {"player": {"Inventory": {"capacity": 1, "items": [PackedInt32Array(), Vector3i.ZERO]}}}}
    var bundle: Dictionary = {"uuid": UUID, "scene_path": DROP, "position": Ref.player.global_position, "save_data": {plain: {"node": {UUID: {"global_position": Ref.player.global_position, "": {"capacity": 1, "items": [PackedInt32Array([7, 4, 0]), Vector3i.ZERO]}}}}}}
    var path: String = presence._profile_path("host")
    presence.personal_store.save_checkpoint(path, empty, 0, presence._ledger_instance_key(instance), plain, [bundle], {DROP: true})
    presence.terrain_epoch = "presence_fixture"
    var picked: Dictionary = presence._collect_durable_pickup(1, "host", instance, UUID, "a".repeat(64), 1, presence.terrain_epoch)
    check(picked.get("revision") == 2 and picked["state"]["node"]["player"]["Inventory"]["items"][0][1] == 4, "real locked capture admits durable host pickup")
    presence._release_chest_inventory_lock()
    Ref.player.disabled = true
    presence.lease_preparing = true
    check(presence._capture_local_state()["active"] and presence._is_local_session_player_active() and not presence._is_local_session_player_targetable(), "lease preparation preserves presence without targeting")
    presence.lease_preparing = false
    presence.lease_frozen = true
    check(presence._capture_local_state()["active"] and not presence._is_local_session_player_targetable(), "frozen lease installation retains presence")
    presence.reconnect_pending = true
    check(not presence._capture_local_state()["active"] and not presence._is_local_session_player_active(), "reconnect cannot be made active by a controlled lock")
    presence.reconnect_pending = false
    presence.lease_frozen = false
    presence.local_downed = true
    check(presence._capture_local_state()["active"] and presence._capture_local_state()["downed"] and not presence._valid_chest_session(1, instance, position), "downed revival presence remains visible but cannot transact")
    presence.local_downed = false
    Ref.player.dead = true
    check(not presence._capture_local_state()["active"] and not presence._is_local_session_player_active(), "dead player remains inactive")
    Ref.player.dead = previous_dead
    Ref.player.disabled = previous_disabled
    Ref.player.set_block_signals(previous_blocked)
    Ref.save_file_manager.loaded_file = previous_file
    presence.free()

func check_disconnected_reclaim() -> void:
    var reclaim := ReclaimManager.new()
    reclaim.fixture_root = "user://lease_reclaim_" + Crypto.new().generate_random_bytes(8).hex_encode()
    reclaim.live = false
    add_child(reclaim)
    var previous_disabled: bool = Ref.player.disabled
    var previous_file = Ref.save_file_manager.loaded_file
    var previous_chunks = Ref.preserve_node_manager.chunk_to_uuid_map.duplicate(true)
    Ref.save_file_manager.loaded_file = SaveFile.new()
    var instance: String = reclaim.get_active_dimension_instance_key()
    var plain: String = SaveFile.DIMENSION_MAP[int(Ref.world.current_dimension)]
    var key: String = reclaim.ChunkAuthority.chunk_key(instance, Vector3i.ZERO)
    var path: String = reclaim._profile_path("guest")
    var empty: Dictionary = {"node": {"player": {"Inventory": {"capacity": 1, "items": [PackedInt32Array(), Vector3i.ZERO]}}}}
    var stale = load(DROP).instantiate()
    get_tree().root.add_child(stale)
    var item := ItemState.new()
    item.id = 7
    item.count = 4
    stale.initialize(item, true)
    stale.disabled = true
    stale.set_meta("coop_synced_drop", true)
    reclaim._bind_sync_uuid(stale, UUID)
    reclaim.tracked_root_drops.append(stale)
    var bundle: Dictionary = reclaim._capture_entity_save_bundle(stale, UUID)
    reclaim._merge_save_data_into_loaded_file(bundle["save_data"])
    reclaim.personal_store.save_checkpoint(path, empty, 0, reclaim._ledger_instance_key(instance), plain, [bundle], {DROP: true})
    reclaim.personal_store.collect_drop(path, 1, "b".repeat(64), reclaim._ledger_instance_key(instance), UUID, func(_id): return 64)
    reclaim.chunk_authority.install_lease(1, {key: 2}, {instance + "|" + UUID: 2})
    reclaim.lease_busy = true
    reclaim.lease_was_disabled = previous_disabled
    check(await reclaim._restore_disconnected_runtime_state() and reclaim.checkpoint_saw_old_barrier, "disconnect checkpoints old lease then installs canonical reclaim")
    check(reclaim.lease_frozen and stale.is_queued_for_deletion() and not reclaim.owns_runtime_node(stale), "durably deleted stale replica stays frozen and is removed before resume")
    await get_tree().process_frame
    check(not is_instance_valid(stale) and reclaim.personal_store.instance_bundles(path, reclaim._ledger_instance_key(instance))["bundles"].is_empty(), "reclaim cannot resurrect collected UUID or generate duplicate loot")
    reclaim._resume_lease_runtime()
    var uuid_live: String = "44444444-4444-4444-8444-444444444444"
    var older = load(DROP).instantiate()
    get_tree().root.add_child(older)
    var older_item := ItemState.new()
    older_item.id = 7
    older_item.count = 1
    older.initialize(older_item, true)
    older.disabled = true
    older.set_meta("coop_synced_drop", true)
    reclaim._bind_sync_uuid(older, uuid_live)
    reclaim.tracked_root_drops.append(older)
    var newer: Dictionary = reclaim._capture_entity_save_bundle(older, uuid_live)
    for entry in newer["save_data"][plain]["node"][uuid_live].values():
        if entry is Dictionary and entry.get("capacity") == 1:
            entry["items"][0][1] = 6
    reclaim._merge_save_data_into_loaded_file(reclaim._capture_entity_save_bundle(older, uuid_live)["save_data"])
    var profile: Dictionary = reclaim.personal_store.read_profile(path)
    reclaim.personal_store.save_checkpoint(path, profile["state"], profile["revision"], reclaim._ledger_instance_key(instance), plain, [newer], {DROP: true})
    reclaim.chunk_authority.install_lease(3, {key: 2}, {instance + "|" + uuid_live: 2})
    reclaim.lease_busy = true
    check(await reclaim._restore_disconnected_runtime_state() and older.is_queued_for_deletion(), "reclaim installs newer canonical live bundle instead of resuming stale copy")
    await get_tree().process_frame
    var restored: Dictionary = Ref.save_file_manager.loaded_file.get_data("node/" + uuid_live, {})
    var restored_count: int = 0
    for entry in restored.values():
        if entry is Dictionary and entry.get("capacity") == 1:
            restored_count = entry["items"][0][1]
    check(not is_instance_valid(older) and restored_count == 6 and restored.get("file_path") == DROP, "new canonical item count and UUID survive old replica deletion")
    reclaim.fail_apply = true
    check(not await reclaim._restore_disconnected_runtime_state() and reclaim.lease_frozen, "failed reclaim installation cannot release gameplay")
    for node in Ref.preserve_node_manager.node_to_uuid_map.keys():
        if is_instance_valid(node) and Ref.preserve_node_manager.node_to_uuid_map[node] in [UUID, uuid_live]:
            node.free()
    Ref.preserve_node_manager.chunk_to_uuid_map.assign(previous_chunks)
    Ref.save_file_manager.loaded_file = previous_file
    Ref.player.disabled = previous_disabled
    reclaim.free()
