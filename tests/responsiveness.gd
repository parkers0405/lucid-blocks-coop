extends Node

class Guest extends "res://coop_mod/coop_manager.gd":
    var instance: String = "dimension:2"
    var live_block: int = 7
    var submitted_block: int = -1
    var profile_captures: int = 0
    func _has_live_peer() -> bool:
        return true
    func _capture_local_persistent_state() -> Dictionary:
        profile_captures += 1
        return {}
    func _ready() -> void:
        pass
    func _physics_process(_delta: float) -> void:
        pass
    func _can_sample_player() -> bool:
        return true
    func _can_transmit_pending_local_world_patch_to_host() -> bool:
        return true
    func get_active_dimension_instance_key() -> String:
        return instance
    func _send_checkpoint_patch_and_wait(patch: Dictionary, _flush: int) -> bool:
        submitted_block = patch["world_data"]["naraka_world"]["naraka_chunk_block"][Vector3i.ZERO][0]
        await get_tree().create_timer(0.15, true, false, true).timeout
        return patch.get("epoch") == terrain_epoch and patch.get("dimension_instance_key") == instance
    func _capture_local_world_patch() -> Dictionary:
        return {"epoch": terrain_epoch, "dimension": 2, "pocket_owner_key": "", "dimension_instance_key": instance, "world_data": {"naraka_world": {"naraka_chunk_block": {Vector3i.ZERO: PackedInt32Array([live_block])}}}}
    func _update_status_text() -> void:
        pass

class Probe extends "res://coop_mod/coop_manager.gd":
    var instance: String = "dimension:2"
    var handoffs: int = 0
    func _ready() -> void:
        pass
    func _physics_process(_delta: float) -> void:
        pass
    func _can_sample_player() -> bool:
        return true
    func _is_local_session_player_active() -> bool:
        return true
    func _has_live_peer() -> bool:
        return true
    func get_active_dimension_instance_key() -> String:
        return instance
    func _local_loaded_lease_chunks() -> Array:
        return []
    func _capture_local_state() -> Dictionary:
        return {"active": true, "dimension_instance_key": instance, "position": Vector3.ZERO}
    func _lease_objects_changed(_chunks: Dictionary) -> bool:
        await get_tree().create_timer(0.15, true, false, true).timeout
        return true
    func _handoff_runtime_lease(_proposal: Dictionary) -> void:
        handoffs += 1

class Pickup extends "res://coop_mod/coop_manager.gd":
    var captures: int = 0
    func _ready() -> void:
        pass
    func _physics_process(_delta: float) -> void:
        pass
    func _can_sample_player() -> bool:
        return true
    func begin_chest_inventory_lock(_movement: bool = true) -> void:
        chest_lock_active = true
    func _capture_local_persistent_state() -> Dictionary:
        return {}
    func _capture_local_instance_nodes() -> Array:
        return []
    func _commit_player_checkpoint(_key: String, _state: Dictionary, _instance: String, _dimension: int, _bundles: Array, _skip: bool = false) -> Dictionary:
        captures += 1
        await get_tree().create_timer(0.15, true, false, true).timeout
        return {}
    func receive_durable_pickup(_request: String, _record: Dictionary, _epoch: String) -> void:
        chest_lock_active = false

class Barrier extends "res://coop_mod/coop_manager.gd":
    var saved_after_lease: bool = false
    func _ready() -> void:
        pass
    func _physics_process(_delta: float) -> void:
        pass
    func _checkpoint_local_host_world() -> bool:
        saved_after_lease = not lease_busy
        return true

class Loading extends Barrier:
    var drains: int = 0
    func _has_live_peer() -> bool:
        return true
    func _is_local_session_player_active() -> bool:
        return false
    func _can_sample_player() -> bool:
        return true
    func _drain_lease_mutations() -> bool:
        drains += 1
        return false

class LeaseCheckpoint extends "res://coop_mod/coop_manager.gd":
    var save_yielded: bool = false
    func _ready() -> void:
        pass
    func _physics_process(_delta: float) -> void:
        pass
    func _can_sample_player() -> bool:
        return true
    func _persist_host_profile(_skip: bool = false) -> bool:
        await get_tree().process_frame
        save_yielded = true
        return true

var finished: bool = false
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("RESPONSIVENESS_FAIL ", label)

func checkpoint(manager: Node, expected: bool = true) -> void:
    check(await manager._checkpoint_terrain_in_background() == expected, "snapshot result matches current instance and epoch")
    finished = true

func probe_lease(manager: Node) -> void:
    await manager._tick_runtime_lease(1.0)
    finished = true

func finish_lease(manager: Node) -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    manager.lease_busy = false

func run() -> int:
    var manager := Guest.new()
    add_child(manager)
    var api := SceneMultiplayer.new()
    var peer := ENetMultiplayerPeer.new()
    check(peer.create_client("127.0.0.1", 9) == OK, "guest transport fixture")
    get_tree().set_multiplayer(api, manager.get_path())
    api.multiplayer_peer = peer
    manager.guest_persistent_ready = true
    manager.receiving_host_world = true
    manager._send_persistent_state_to_host(true)
    manager.receiving_host_world = false
    manager.client_restore_in_progress = true
    manager._send_persistent_state_to_host(true)
    manager.client_restore_in_progress = false
    manager.reconnect_pending = true
    manager._send_persistent_state_to_host(true)
    manager.reconnect_pending = false
    check(manager.profile_captures == 0, "half-restored character cannot publish a profile even when forced")
    var skipped_restores: bool = true
    for state_flag in ["receiving_host_world", "client_restore_in_progress", "reconnect_pending", "suppress_local_game_quit_session_shutdown"]:
        manager.set(state_flag, true)
        skipped_restores = skipped_restores and not await manager._checkpoint_terrain_in_background()
        manager.set(state_flag, false)
    check(skipped_restores and manager.submitted_block == -1, "routine checkpoint skips restoration without reading native terrain")
    manager.guest_checkpoint_was_disabled = true
    manager.background_checkpoint_busy = true
    Ref.player.disabled = false
    check(not manager._disabled_before_checkpoint(), "routine checkpoint cannot restore a stale disabled state during handoff")
    manager.background_checkpoint_busy = false
    manager.terrain_epoch = "fixture:1"
    var disabled: bool = Ref.player.disabled
    var mode: int = Ref.world.process_mode
    Ref.player.disabled = false
    checkpoint(manager)
    await get_tree().process_frame
    check(not Ref.player.disabled and Ref.world.process_mode == mode, "delayed checkpoint keeps player and world processing enabled")
    check(not manager.guest_checkpoint_busy, "routine save does not occupy the durable barrier lock")
    manager.live_block = 8
    while not finished:
        await get_tree().process_frame
    check(manager.live_block == 8 and manager.submitted_block == 7, "new edit survives an older in-flight snapshot")
    finished = false
    checkpoint(manager, false)
    await get_tree().process_frame
    manager.terrain_epoch = "fixture:2"
    while not finished:
        await get_tree().process_frame
    check(not manager.guest_checkpoint_busy and manager.live_block == 8, "lease change rejects stale snapshot without touching newer local state")
    Ref.player.disabled = disabled
    Ref.world.process_mode = mode
    manager._ensure_remote_world_scope()
    manager.pending_remote_block_changes[Vector3i.ZERO] = 7
    manager.pending_remote_storage_changes[Vector3i.ZERO] = []
    manager.instance = "pocket:alice"
    manager._ensure_remote_world_scope()
    check(manager.pending_remote_block_changes.is_empty() and manager.pending_remote_storage_changes.is_empty(), "pending world changes never cross instance boundaries")
    peer.close()
    api.multiplayer_peer = OfflineMultiplayerPeer.new()
    get_tree().set_multiplayer(null, manager.get_path())
    manager.free()
    var probe := Probe.new()
    add_child(probe)
    probe.chunk_authority.lease_epoch = 1
    probe.admitted_player_keys[2] = "guest"
    probe.lease_guest_instance = "dimension:2"
    probe.terrain_epoch = "probe:1"
    finished = false
    probe_lease(probe)
    await get_tree().process_frame
    probe.instance = "pocket:alice"
    while not finished:
        await get_tree().process_frame
    await get_tree().process_frame
    check(probe.handoffs == 0 and not probe.lease_probe_busy, "old lease probe cannot freeze a newly entered dimension")
    probe.free()
    var pickup := Pickup.new()
    add_child(pickup)
    var first := Node3D.new()
    var second := Node3D.new()
    add_child(first)
    add_child(second)
    var previous_held = Ref.player.held_item
    var glider := HeldGlider.new()
    glider.gliding = true
    Ref.player.held_item = glider
    first.set_meta("coop_pickup_pending_request", true)
    pickup._begin_durable_pickup(first)
    check(pickup.captures == 0 and not first.get_meta("coop_pickup_pending_request") and glider.gliding, "automatic pickup waits without interrupting an active glide")
    Ref.player.held_item = previous_held
    glider.free()
    second.set_meta("coop_pickup_pending_request", true)
    pickup.host_profile_busy = true
    pickup._begin_durable_pickup(first)
    pickup._begin_durable_pickup(second)
    await get_tree().process_frame
    pickup.host_profile_busy = false
    await get_tree().process_frame
    await get_tree().process_frame
    check(pickup.captures == 1 and second.get_meta("coop_pickup_pending_request"), "second pickup remains queued while first reserves inventory")
    while pickup.chest_lock_active:
        await get_tree().process_frame
    var pickup_deadline: int = Time.get_ticks_msec() + 2000
    while (pickup.captures < 2 or pickup.chest_lock_active) and Time.get_ticks_msec() < pickup_deadline:
        await get_tree().process_frame
    check(pickup.captures == 2, "queued second pickup runs after first acknowledgement")
    Ref.preserve_node_manager.node_to_uuid_map.erase(first)
    Ref.preserve_node_manager.node_to_uuid_map.erase(second)
    first.free()
    second.free()
    pickup.free()
    var barrier := Barrier.new()
    add_child(barrier)
    barrier.lease_busy = true
    finish_lease(barrier)
    check(await barrier._await_local_world_checkpoint() and barrier.saved_after_lease, "quit or travel checkpoint waits for ownership recovery to finish")
    barrier.free()
    var loading := Loading.new()
    add_child(loading)
    loading._tick_canonical_terrain(3.0)
    check(not Ref.world.is_all_loaded() and loading.terrain_sync_timer == 0.0, "routine terrain capture defers while native workers load chunks")
    await loading._handoff_runtime_lease({})
    check(loading.drains == 0 and not loading.lease_busy, "loading player cannot start a handoff that preserves disabled input")
    loading.free()
    var streaming := LeaseCheckpoint.new()
    add_child(streaming)
    streaming.lease_checkpoint_allowed = true
    streaming.lease_frozen = true
    var before_checkpoint: int = Time.get_ticks_msec()
    check(not await streaming._checkpoint_local_host_world() and streaming.save_yielded and Time.get_ticks_msec() - before_checkpoint < 1000, "lease checkpoint aborts promptly if streaming is active after asynchronous profile IO")
    streaming.free()
    var living := Guest.new()
    add_child(living)
    var living_mismatch: int = 0
    for id in ItemMap.all_item_ids:
        var block = ItemMap.map(id)
        if block is Block and living._get_living_block_scene_path(id) != str(block.living_block_path):
            living_mismatch += 1
    check(living_mismatch == 0, "living block scene path reads the 5.2 Block property for every block")
    living.free()
    print("RESPONSIVENESS_RESULT ", checks, " checks ", failures, " failures")
    return failures
