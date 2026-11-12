extends Node
const DROP: String = "res://main/items/dropped_item/dropped_item.tscn"
const UUID: String = "33333333-3333-4333-8333-333333333333"
class TravelEntity extends Entity:
    func _ready() -> void:
        pass
    func is_session_position_loaded(_position: Vector3) -> bool:
        return true

class Manager extends "res://coop_mod/coop_manager.gd":
    var fixture_root: String
    var live: bool = true
    func _ready() -> void:
        pass
    func _physics_process(_delta: float) -> void:
        pass
    func _is_local_session_player_active() -> bool:
        return true
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
class RaceManager extends Manager:
    var flip: Callable
    func _private_respawn_checkpoint(_key: String, _state: Dictionary, _instance: String, _dimension: int) -> Dictionary:
        await get_tree().process_frame
        if flip.is_valid():
            flip.call()
        return {"ok": true, "update": {}}
class PrepareManager extends Manager:
    var order: Array = []
    func _await_profile_checkpoint() -> bool:
        order.append("profile")
        return true
    func _checkpoint_terrain_in_background() -> bool:
        order.append("terrain")
        return true
class SwitchManager extends Manager:
    var jobs: Array = []
    var kicked: Array = []
    func _store_job(store: RefCounted, method: String, arguments: Array, fallback: Variant) -> Variant:
        jobs.append(method)
        return await super(store, method, arguments, fallback)
    func _lease_kick_peer(peer: int) -> void:
        kicked.append(peer)
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
class SlowQueue extends "res://coop_mod/save_queue.gd":
    func _execute(job: Job) -> void:
        OS.delay_msec(100)
        job.result = job.operation.call()
class DropProbe extends Node3D:
    var can_merge: bool = true
class PickupRace extends Manager:
    var drop: Node3D
    func _find_existing_drop_by_uuid(_uuid: String):
        return drop
    func _apply_pickup_remainder(_uuid: String, _bundle: Dictionary) -> void:
        pass
    func _has_live_peer() -> bool:
        return false
class CheckpointResumeManager extends Manager:
    func _drain_lease_mutations() -> bool:
        return false
class ReclaimManager extends Manager:
    var checkpoint_saw_old_barrier: bool = false
    var fail_apply: bool = false
    var replace_token: bool = false
    var expected_uuid: String = ""
    var checkpoint_has_committed_bundle: bool = false
    func get_active_dimension_instance_key() -> String:
        return "dimension:" + str(int(Ref.world.current_dimension))
    func _local_loaded_lease_chunks() -> Array:
        return [Vector3i.ZERO]
    func _checkpoint_local_host_world() -> bool:
        checkpoint_saw_old_barrier = lease_frozen and lease_checkpoint_allowed
        if not expected_uuid.is_empty():
            var saved: Dictionary = Ref.save_file_manager.loaded_file.get_data("node/" + expected_uuid, {})
            for entry in saved.values():
                if entry is Dictionary and entry.get("capacity") == 1:
                    checkpoint_has_committed_bundle = entry["items"][0][1] == 6
        return true
    func _apply_canonical_terrain(_patch: Dictionary) -> bool:
        if replace_token:
            await get_tree().process_frame
            lease_token = "replacement"
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
    var viewport := SubViewport.new()
    viewport.own_world_3d = true
    viewport.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(viewport)
    var body: Entity = load("res://main/entity/entity.tscn").instantiate()
    body.set_script(TravelEntity)
    var enabler = body.get_node("%VisibleOnScreenEnabler3D")
    enabler.enable_node_path = NodePath("")
    enabler.process_mode = Node.PROCESS_MODE_DISABLED
    body.process_mode = Node.PROCESS_MODE_ALWAYS
    viewport.add_child(body)
    body.set_physics_process(false)
    body.set_process(false)
    var space: RID = PhysicsServer3D.body_get_space(body.get_rid())
    check(space.is_valid() and body.is_future_position_loaded(0.0), "attached physics body can move in its loaded area")
    PhysicsServer3D.body_set_space(body.get_rid(), RID())
    check(not body.is_future_position_loaded(0.0), "detached travel body cannot attempt motion even while terrain remains loaded")
    PhysicsServer3D.body_set_space(body.get_rid(), space)
    body.free()
    viewport.free()
    var checkpoint_manager := CheckpointResumeManager.new()
    add_child(checkpoint_manager)
    var originally_disabled: bool = Ref.player.disabled
    for initially_disabled in [false, true]:
        checkpoint_manager.guest_checkpoint_busy = true
        checkpoint_manager.guest_checkpoint_locks_player = true
        checkpoint_manager.guest_checkpoint_was_disabled = initially_disabled
        Ref.player.disabled = true
        checkpoint_manager.lease_was_disabled = checkpoint_manager._disabled_before_checkpoint()
        checkpoint_manager._resume_lease_runtime()
        check(Ref.player.disabled, "lease cancellation preserves active checkpoint lock")
        checkpoint_manager.guest_checkpoint_busy = false
        checkpoint_manager.guest_checkpoint_locks_player = false
        checkpoint_manager._resume_lease_runtime()
        check(Ref.player.disabled == initially_disabled, "lease resume restores original state rather than temporary checkpoint lock")
    Ref.player.disabled = originally_disabled
    checkpoint_manager.free()
    # H6: a profile checkpoint filters its bundles with the ownership view it started under, and counts itself while in flight.
    var race := RaceManager.new()
    race.fixture_root = "user://lease_race_" + Crypto.new().generate_random_bytes(8).hex_encode()
    add_child(race)
    var race_key: String = race.ChunkAuthority.chunk_key("dimension:2", Vector3i.ZERO)
    var race_object: String = "dimension:2|" + UUID
    race.chunk_authority.install_lease(1, {race_key: 1}, {race_object: 1})
    var race_path: String = race._profile_path("host")
    check(race.personal_store.commit_lease(race_path, 1, {race_key: 1}, {}, []), "race fixture durable epoch 1")
    var race_bundle: Dictionary = {"uuid": UUID, "position": Vector3.ZERO, "scene_path": DROP, "save_data": {"naraka": {"node": {UUID: {"global_position": Vector3.ZERO}}}}}
    var race_state: Dictionary = {"_coop_revision": 0, "node": {"player": {}}}
    check((await race._commit_player_checkpoint("host", race_state, "dimension:2", 2, [race_bundle])).get("revision") == 1, "race fixture host owns the object durably")
    race.flip = func(): race.chunk_authority.install_lease(2, {race_key: 2}, {race_object: 2})
    race_state["_coop_revision"] = 1
    var in_flight := {"done": false}
    var in_flight_runner := func():
        in_flight["result"] = await race._commit_player_checkpoint("host", race_state, "dimension:2", 2, [race_bundle])
        in_flight["done"] = true
    in_flight_runner.call_deferred()
    await get_tree().process_frame
    check(int(race.get("checkpoints_in_flight")) == 1, "checkpoint counts itself while in flight")
    while not in_flight["done"]:
        await get_tree().process_frame
    var race_result: Dictionary = in_flight["result"]
    var race_ledger: Dictionary = race.personal_store.read_ledger(race_path)
    check(not race_result.is_empty() and not race_ledger["instances"]["dimension__2"]["tombstones"].has(UUID) and race_ledger["instances"]["dimension__2"]["owners"].get(UUID) == "host", "epoch flipped during the checkpoint does not tombstone the object")
    check(int(race.get("checkpoints_in_flight")) == 0, "in-flight counter returns to zero")
    race.free()
    # H7: transit set, peer epoch window, and routine capture that skips chunks in transit.
    var window := Manager.new()
    window.fixture_root = "user://lease_window_" + Crypto.new().generate_random_bytes(8).hex_encode()
    add_child(window)
    window.terrain_epoch = "nonce:2"
    check(window.has_method("_peer_epoch_ok") and window._peer_epoch_ok("nonce:2") and not window._peer_epoch_ok("nonce:1"), "outside a window only the exact epoch is accepted")
    window.set("lease_window_epoch", "nonce:1")
    check(window.has_method("_peer_epoch_ok") and window._peer_epoch_ok("nonce:1") and window._peer_epoch_ok("nonce:2") and not window._peer_epoch_ok("nonce:0"), "inside a window the previous epoch is also accepted")
    window.set("lease_window_epoch", "")
    check(window.has_method("_peer_epoch_ok") and not window._peer_epoch_ok("nonce:1"), "window closed again after activation")
    var transit_actor := Node3D.new()
    transit_actor.set_meta("coop_uuid", UUID)
    add_child(transit_actor)
    var window_key: String = window.ChunkAuthority.chunk_key("dimension:2", Vector3i.ZERO)
    window.chunk_authority.install_lease(1, {window_key: 1}, {"dimension:2|" + UUID: 1})
    check(window.owns_runtime_node(transit_actor), "owned node simulates before transit")
    var transit = window.get("lease_transit")
    if transit is Dictionary:
        transit["dimension:2|" + UUID] = true
    check(not window.owns_runtime_node(transit_actor), "node in transit is not owned until the install")
    if transit is Dictionary:
        transit.clear()
    var chunks_in_transit = window.get("lease_transit_chunks")
    var skip_data: Dictionary = {"naraka_world": {"naraka_chunk_block": {Vector3i.ZERO: PackedInt32Array([1]), Vector3i(16, 0, 0): PackedInt32Array([1])}, "naraka_chunk_water": {}, "naraka_chunk_water_awake": {}, "naraka_chunk_fire": {}}}
    if chunks_in_transit is Dictionary:
        chunks_in_transit[window.ChunkAuthority.chunk_key("dimension:2", Vector3i.ZERO)] = true
    var kept: Dictionary = window.filter_local_checkpoint(skip_data, "naraka_")
    check(chunks_in_transit is Dictionary and not kept.get("naraka_world", {}).get("naraka_chunk_block", {}).has(Vector3i.ZERO), "chunk in transit is absent from the routine host checkpoint")
    window.free()
    transit_actor.free()
    # H8: pre-prepare hold and READY ordering.
    var prep := PrepareManager.new()
    prep.fixture_root = "user://lease_prep_" + Crypto.new().generate_random_bytes(8).hex_encode()
    add_child(prep)
    check(prep.has_method("_lease_hold_active") and not prep._lease_hold_active(), "no hold without a prepare")
    prep.set("lease_prepared_token", "t1")
    prep.set("lease_hold_until", Time.get_ticks_msec() + 60000)
    check(prep.has_method("_lease_hold_active") and prep._lease_hold_active(), "prepare holds routine terrain submits")
    prep.cancel_runtime_lease("t1", prep.terrain_epoch)
    check(prep.has_method("_lease_hold_active") and not prep._lease_hold_active() and not prep.lease_busy, "cancel releases the hold without touching the lease state")
    prep.set("lease_prepared_token", "t2")
    prep.set("lease_hold_until", Time.get_ticks_msec() - 1)
    check(prep.has_method("_lease_hold_active") and not prep._lease_hold_active() and prep.get("lease_prepared_token") == "", "timeout releases the hold")
    prep.set("lease_prepared_token", "t3")
    prep.set("lease_hold_until", Time.get_ticks_msec() + 60000)
    prep.background_checkpoint_busy = true
    var presync := {"done": false, "ok": false}
    var presync_runner := func():
        presync["ok"] = await prep.call("_lease_presync", "t3")
        presync["done"] = true
    presync_runner.call_deferred()
    await get_tree().process_frame
    await get_tree().process_frame
    check(prep.order.is_empty() and not presync["done"], "READY work does not start while a routine checkpoint is in flight")
    prep.background_checkpoint_busy = false
    while not presync["done"]:
        await get_tree().process_frame
    check(presync["ok"] == true and prep.order == ["profile", "terrain"], "presync saves the profile, then the terrain delta")
    prep.free()
    # H9: switch outcomes on the host. The remote sender id of a direct call is 0, so the fixture admits peer 0.
    var sw := SwitchManager.new()
    sw.fixture_root = "user://lease_switch_" + Crypto.new().generate_random_bytes(8).hex_encode()
    add_child(sw)
    var sw_key: String = sw.ChunkAuthority.chunk_key("dimension:2", Vector3i.ZERO)
    var sw_object: String = "dimension:2|" + UUID
    var sw_path: String = sw._profile_path("host")
    sw.admitted_player_keys[0] = "guest"
    sw.chunk_authority.install_lease(1, {}, {})
    sw.terrain_epoch = "nonce:1"
    sw.lease_busy = true
    sw.lease_phase = "switching"
    sw.lease_token = "tok"
    sw.lease_switch_ctx = {"token": "tok", "epoch": 2, "proposal": {sw_key: 2}, "objects": {sw_object: 2}, "transfers": [], "path": sw_path, "previous_epoch": 1, "previous_chunks": {}, "instance": "dimension:2", "generation": sw.save_queue.generation}
    sw.lease_transit[sw_object] = true
    sw.lease_transit_chunks[sw_key] = true
    await sw.lease_switched("tok", 2, false, PackedByteArray())
    check(sw.chunk_authority.lease_epoch == 1 and sw.terrain_epoch == "nonce:1" and sw.lease_transit.is_empty() and sw.lease_transit_chunks.is_empty() and not sw.lease_busy and sw.lease_phase == "" and sw.jobs.is_empty(), "SWITCHED(false) leaves memory, tag and disk queue at the old epoch with nothing in transit")
    sw.lease_busy = true
    sw.lease_phase = "switching"
    sw.lease_switch_ctx = {"token": "tok", "epoch": 2, "proposal": {sw_key: 2}, "objects": {sw_object: 2}, "transfers": [], "path": sw_path, "previous_epoch": 1, "previous_chunks": {}, "instance": "dimension:2", "generation": sw.save_queue.generation}
    sw.lease_transit[sw_object] = true
    await sw.lease_switched("tok", 2, true, PackedByteArray([1, 2, 3]))
    check(sw.kicked == [0] and sw.chunk_authority.lease_epoch == 1 and sw.lease_transit.is_empty() and not sw.lease_busy, "invalid SWITCHED body sends the guest to reconnect and changes nothing")
    check(sw._lease_pickup_blocked("dimension:2", UUID) == false or sw.lease_transit.has(sw_object) == false, "pickup helper agrees with the transit set")
    sw.lease_transit[sw_object] = true
    check(sw._lease_pickup_blocked("dimension:2", UUID), "an object in transit cannot be picked up")
    sw.lease_transit.clear()
    sw.lease_busy = true
    sw.lease_phase = "switching"
    sw.lease_switch_ctx = {"token": "tok", "epoch": 2, "proposal": {sw_key: 3}, "objects": {}, "transfers": [], "path": sw_path, "previous_epoch": 1, "previous_chunks": {}, "instance": "dimension:2", "generation": sw.save_queue.generation}
    sw.kicked.clear()
    await sw.lease_switched("tok", 2, true, sw._pack_body({"bundles": [], "terrain": {}, "instance": "dimension:2"}))
    check(sw.kicked == [0] and sw.chunk_authority.lease_epoch == 1 and not sw.lease_busy, "a host install failure after the guest flipped kicks the guest instead of leaving the peers split")
    sw.lease_busy = true
    sw.lease_phase = "switching"
    sw.lease_switch_ctx = {"token": "tok", "epoch": 2, "proposal": {sw_key: 2}, "objects": {sw_object: 2}, "transfers": [], "path": sw_path, "previous_epoch": 1, "previous_chunks": {}, "instance": "dimension:2", "generation": sw.save_queue.generation}
    sw.lease_transit[sw_object] = true
    sw.inflight_by_epoch[1] = 1
    var good_body: PackedByteArray = sw._pack_body({"bundles": [], "terrain": {}, "instance": "dimension:2"})
    var switched := {"done": false}
    var switched_runner := func():
        await sw.lease_switched("tok", 2, true, good_body)
        switched["done"] = true
    switched_runner.call_deferred()
    await get_tree().process_frame
    await get_tree().process_frame
    check(sw.chunk_authority.lease_epoch == 2 and sw.terrain_epoch == "nonce:2" and sw.lease_transit.is_empty() and not sw.lease_busy and not sw._is_client_gameplay_locked() and not sw.lease_frozen and not sw.lease_preparing, "valid SWITCHED flips memory and tag in the same step without freezing or locking anything")
    check(not sw.jobs.has("commit_lease") and sw.lease_commit_gate_epoch == 2, "write-behind waits for the old epoch's in-flight checkpoint before the commit")
    sw.inflight_by_epoch[1] = 0
    var gate_deadline: int = Time.get_ticks_msec() + 10000
    while (not switched["done"] or sw.lease_commit_gate_epoch != 0) and Time.get_ticks_msec() < gate_deadline:
        await get_tree().process_frame
    check(sw.jobs.has("commit_lease") and sw.personal_store.read_ledger(sw_path)["lease"]["epoch"] == 2 and sw.lease_commit_gate_epoch == 0, "ownership commit lands after the wait and releases the gate")
    sw.free()
    var manager := Manager.new()
    manager.fixture_root = "user://lease_runtime_" + Crypto.new().generate_random_bytes(8).hex_encode()
    add_child(manager)
    var actor := Node3D.new()
    actor.set_meta("coop_uuid", UUID)
    add_child(actor)
    var key: String = manager.ChunkAuthority.chunk_key("dimension:2", Vector3i.ZERO)
    check(manager.chunk_authority.install_lease(1, {key: 2}, {"dimension:2|" + UUID: 2}), "runtime fixture installs granted guest owner")
    check(not manager.owns_runtime_node(actor) and not manager.can_mutate_runtime_node(actor), "host replica cannot process or mutate guest UUID")
    check(manager.personal_store.commit_lease(manager._profile_path("host"), 1, {key: 2}, {}, []), "fixture durable lease agrees with runtime epoch")
    manager.peer_states[2] = {"active": true, "downed": false, "dimension_instance_key": "dimension:2"}
    manager.admitted_player_keys[2] = "guest"
    manager.terrain_epoch = "session:1"
    check(manager._valid_runtime_sender(2, "session:1") and not manager._valid_runtime_sender(2, "session:0"), "current epoch admitted sender passes and late epoch fails")
    manager.lease_frozen = true
    check(not manager._valid_runtime_sender(2, "session:1"), "frozen runtime rejects mutation RPC")
    var state: Dictionary = {"_coop_revision": 0, "node": {"player": {}}}
    check((await manager._commit_player_checkpoint("host", state, "dimension:2", 2, [])).is_empty(), "install phase cannot tombstone missing UUID via profile checkpoint")
    manager.lease_checkpoint_allowed = true
    check((await manager._commit_player_checkpoint("host", state, "dimension:2", 2, [])).get("revision") == 1, "explicit old-lease barrier checkpoint remains allowed while frozen")
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
    var host_path: String = manager._profile_path("host")
    manager.lease_recommit_needed = true
    manager.lease_recommit_epoch = 2
    manager.lease_recommit_failures = 2
    await manager._commit_lease_write_behind(host_path, 2, {key: 2}, {}, [])
    check(manager.personal_store.read_ledger(host_path)["lease"]["epoch"] == 2 and not manager.lease_recommit_needed and manager.lease_recommit_failures == 0, "write-behind ownership commit becomes durable and clears the recommit state")
    await manager._commit_lease_write_behind(host_path, 5, {key: 2}, {}, [{"instance": "dimension__2", "uuid": "missing", "old": "host", "new": "guest"}])
    check(manager.lease_recommit_needed and manager.lease_recommit_epoch == 5 and manager.lease_recommit_failures == 1 and manager.personal_store.read_ledger(host_path)["lease"]["epoch"] == 2, "failed write-behind commit keeps the durable epoch and schedules a backed-off recommit")
    check(not manager._lease_recommit_due(), "recommit waits for its backoff timer")
    await manager._commit_lease_write_behind(host_path, 3, {key: 2}, {}, [])
    check(manager.lease_recommit_needed and manager.personal_store.read_ledger(host_path)["lease"]["epoch"] == 3, "an older commit succeeding cannot clear a newer commit's failure")
    manager.lease_recommit_failures = manager.LEASE_RECOMMIT_MAX_FAILURES
    manager.lease_recommit_after = 0
    check(not manager._lease_recommit_due(), "recommit cycling stops after repeated failures")
    manager.lease_recommit_failures = 0
    var before: Dictionary = {"epoch": manager.chunk_authority.lease_epoch, "owners": manager.chunk_authority.lease_owners.duplicate(), "objects": manager.chunk_authority.lease_objects.duplicate(), "terrain_epoch": manager.terrain_epoch}
    manager.chunk_authority.install_lease(before["epoch"] + 1, {key: 1}, {})
    manager.terrain_epoch = "session:other"
    manager.lease_pending_install_epoch = 99
    manager._rollback_pending_lease(before)
    check(manager.chunk_authority.lease_epoch == before["epoch"] and manager.terrain_epoch == before["terrain_epoch"] and manager.lease_pending_install_epoch == 0 and manager.chunk_authority.lease_owners == before["owners"], "empty install payload rolls memory back to the durable epoch")
    manager.lease_recommit_needed = false
    manager.lease_recommit_epoch = 0
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
    await check_pickup_race()
    await check_presence_capture()
    await check_disconnected_reclaim()
    trace_orphan_inventories("after_reclaim_fixture")
    print("LEASE_RUNTIME_RESULT ", checks, " checks ", failures, " failures")
    return failures

var pickup_race_result: Dictionary = {}
var pickup_race_done: bool = false
func launch_pickup_race(manager: Node, instance: String) -> void:
    pickup_race_result = await manager._collect_durable_pickup(1, "host", instance, UUID, "c".repeat(64), 1, manager.terrain_epoch)
    pickup_race_done = true

func check_pickup_race() -> void:
    var race := PickupRace.new()
    race.fixture_root = "user://pickup_race_" + str(Time.get_ticks_usec())
    add_child(race)
    race.drop = DropProbe.new()
    add_child(race.drop)
    race.drop.process_mode = Node.PROCESS_MODE_ALWAYS
    race.terrain_epoch = "race"
    race.save_queue = SlowQueue.new()
    var empty: Dictionary = {"node": {"player": {"Inventory": {"capacity": 1, "items": [PackedInt32Array(), Vector3i.ZERO]}}}}
    var bundle: Dictionary = {"uuid": UUID, "scene_path": DROP, "position": Vector3.ZERO, "save_data": {"naraka": {"node": {UUID: {"global_position": Vector3.ZERO, "": {"capacity": 1, "items": [PackedInt32Array([7, 4, 0]), Vector3i.ZERO]}}}}}}
    race.personal_store.save_checkpoint(race._profile_path("host"), empty, 0, "dimension__2", "naraka", [bundle], {DROP: true})
    pickup_race_done = false
    launch_pickup_race(race, "dimension:2")
    await get_tree().process_frame
    var duplicate: Dictionary = await race._collect_durable_pickup(1, "host", "dimension:2", UUID, "d".repeat(64), 1, "race")
    check(duplicate.is_empty(), "same UUID is claimed before first file await")
    while not pickup_race_done:
        await get_tree().process_frame
    check(pickup_race_result.get("revision") == 2 and race.drop.process_mode == Node.PROCESS_MODE_ALWAYS and race.drop.can_merge and race.pickup_claims.is_empty(), "interleaved pickup restores drop mode and merging exactly once")
    race.drop.free()
    race.free()

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
    var picked: Dictionary = (await presence._collect_durable_pickup(1, "host", instance, UUID, "a".repeat(64), 1, presence.terrain_epoch))
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
    presence.suppress_local_game_quit_session_shutdown = true
    check(not presence._is_local_session_player_active(), "native dimension loading cannot start another lease even after player initialization")
    presence.suppress_local_game_quit_session_shutdown = false
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
    reclaim.personal_store.commit_lease(path, 1, {key: 2}, {instance + "|" + UUID: 2}, [])
    reclaim.chunk_authority.install_lease(1, {key: 2}, {instance + "|" + UUID: 2})
    reclaim.lease_busy = true
    reclaim.lease_was_disabled = previous_disabled
    check(await reclaim._restore_disconnected_runtime_state() and reclaim.checkpoint_saw_old_barrier, "disconnect checkpoints old lease then installs canonical reclaim")
    check(reclaim.lease_frozen and (not is_instance_valid(stale) or stale.is_queued_for_deletion()), "durably deleted stale replica stays frozen and is removed before resume")
    await get_tree().process_frame
    check(not is_instance_valid(stale) and reclaim.personal_store.instance_bundles(path, reclaim._ledger_instance_key(instance))["bundles"].is_empty(), "reclaim cannot resurrect collected UUID or generate duplicate loot")
    check((await reclaim._lease_install_payload("pocket:../alice", [], {})).is_empty(), "object-only handoff rejects invalid instance namespace")
    var compact: Dictionary = await reclaim._lease_install_payload(instance, [Vector3i.ZERO], {key: 2})
    check(compact.get("parts", []).size() == 1 and compact["parts"][0]["deleted"].has(UUID), "empty terrain does not add a handoff round trip or hide tombstones")
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
    reclaim.personal_store.commit_lease(path, 3, {key: 2}, {instance + "|" + uuid_live: 2}, [])
    # The map committed, but its durable objects have not been installed yet.
    reclaim.lease_pending_previous_chunks = reclaim.chunk_authority.lease_owners.duplicate()
    reclaim.lease_pending_install_epoch = 3
    reclaim.chunk_authority.install_lease(3, {key: 2}, {instance + "|" + uuid_live: 2})
    reclaim.expected_uuid = uuid_live
    reclaim.lease_busy = true
    check(await reclaim._restore_disconnected_runtime_state() and reclaim.checkpoint_has_committed_bundle and (not is_instance_valid(older) or older.is_queued_for_deletion()), "reclaim installs newer canonical live bundle instead of resuming stale copy")
    await get_tree().process_frame
    var restored: Dictionary = Ref.save_file_manager.loaded_file.get_data("node/" + uuid_live, {})
    var restored_count: int = 0
    for entry in restored.values():
        if entry is Dictionary and entry.get("capacity") == 1:
            restored_count = entry["items"][0][1]
    check(not is_instance_valid(older) and restored_count == 6 and restored.get("file_path") == DROP, "new canonical item count and UUID survive old replica deletion")
    var offscreen: Dictionary = await reclaim._lease_install_payload(instance, [], reclaim.chunk_authority.lease_owners.duplicate())
    var retained: bool = false
    for part in offscreen.get("parts", []):
        for entry in part.get("bundles", []):
            retained = retained or entry["uuid"] == uuid_live
    check(retained, "offscreen owned objects enter canonical save cache even without a chunk transfer")
    reclaim.fail_apply = true
    check(not await reclaim._restore_disconnected_runtime_state() and reclaim.lease_frozen, "failed reclaim installation cannot release gameplay")
    reclaim.fail_apply = false
    reclaim.replace_token = true
    check(not await reclaim._install_lease_payload({"dimension_instance_key": instance, "deleted": [uuid_live]}) and not Ref.save_file_manager.loaded_file.get_data("node/" + uuid_live, {}).is_empty(), "replaced lease cannot delete objects after a yielded terrain installation")
    for node in Ref.preserve_node_manager.node_to_uuid_map.keys():
        if is_instance_valid(node) and Ref.preserve_node_manager.node_to_uuid_map[node] in [UUID, uuid_live]:
            node.free()
    Ref.preserve_node_manager.chunk_to_uuid_map.assign(previous_chunks)
    Ref.save_file_manager.loaded_file = previous_file
    Ref.player.disabled = previous_disabled
    reclaim.free()
