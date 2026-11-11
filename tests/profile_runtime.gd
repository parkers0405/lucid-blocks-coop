extends Node

class Manager extends "res://coop_mod/coop_manager.gd":
    var fixture_root: String
    var reconnect_reason_seen: String = ""
    var travelled: Array = []
    var transfers: Array = []
    var pickup_inventory_counts: Array = []
    func _ready() -> void:
        pass
    func _physics_process(_delta: float) -> void:
        pass
    func _can_sample_player() -> bool:
        return true
    func _get_local_player_key() -> String:
        return "fixture_host"
    func _get_checkpoint_chunks_directory() -> String:
        return fixture_root.path_join("chunks")
    func _capture_local_state() -> Dictionary:
        return {"dimension_instance_key": "naraka", "position": Vector3.ZERO, "active": true}
    func _capture_local_persistent_state() -> Dictionary:
        var items: Array = []
        for item in Ref.player_inventory.items:
            items.append(item.get_save_data() if item != null else PackedInt32Array())
            items.append(item.get_position() if item != null else Vector3i.ZERO)
        return {"_coop_revision": profile_revision, "node": {"player": {"Inventory": {"items": items, "capacity": Ref.player_inventory.capacity}}}}
    func _capture_local_instance_nodes() -> Array:
        return []
    func get_active_dimension_instance_key() -> String:
        return "dimension:" + str(int(Ref.world.current_dimension))
    func _begin_reconnect_flow(reason: String) -> void:
        reconnect_reason_seen = reason
    func _apply_received_pickup(_data: PackedInt32Array) -> void:
        pickup_inventory_counts.append(Ref.player_inventory.items[0].count)
    func _update_status_text() -> void:
        pass
    func _open_dimension_instance_async(dimension: int, owner: String = "") -> void:
        travelled.append([dimension, owner])
    func transfer_personal_chest(token: String, revision: int, inventory_name: String, index: int, chest_index: int, amount: int, deposit: bool) -> void:
        transfers.append([token, revision, inventory_name, index, chest_index, amount, deposit])

class RestoreOrder extends Manager:
    var calls: Array = []
    func _broadcast_local_state_now() -> void:
        calls.append("presence")
    func _send_persistent_state_to_host(_force: bool = false) -> void:
        calls.append("profile")

class AccessBlock extends Node3D:
    var broken: bool = false

class SlowQueue extends "res://coop_mod/save_queue.gd":
    func _execute(job: Job) -> void:
        OS.delay_msec(150)
        job.result = job.operation.call()

class FailedStore extends "res://coop_mod/personal_store.gd":
    func _write_ledger(_path: String, _record: Dictionary) -> bool:
        return false

var background_done: bool = false
var frame_count: int = 0
func _process(_delta: float) -> void:
    frame_count += 1
func save_in_background(manager: Node) -> void:
    await manager._persist_host_profile(true)
    background_done = true
func restore_in_background(manager: Node) -> void:
    await manager._restore_host_profile()
    background_done = true

var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("PROFILE_RUNTIME_FAIL ", label)

func run() -> int:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var order := RestoreOrder.new()
    add_child(order)
    order._finish_guest_character_restore()
    check(order.calls == ["presence", "profile"], "restored dimension presence is sent reliably before its profile")
    order.free()
    var original_dead: bool = Ref.player.dead
    Ref.player.dead = false
    var original_player_mode: int = Ref.player.process_mode
    Ref.player.process_mode = Node.PROCESS_MODE_DISABLED
    var previous: Array = [Ref.player_inventory, Ref.player_hotbar, Ref.player_equipment, Ref.player_fusion_source, Ref.player_fusion_result]
    var inventory := Inventory.new()
    inventory.name = "Inventory"
    inventory.capacity = 2
    add_child(inventory)
    Ref.player_inventory = inventory
    Ref.player_hotbar = null
    Ref.player_equipment = null
    Ref.player_fusion_source = null
    Ref.player_fusion_result = null
    var manager := Manager.new()
    manager.fixture_root = "user://profile-runtime-" + Crypto.new().generate_random_bytes(8).hex_encode()
    add_child(manager)
    var state: Dictionary = {"node": {"player": {"Inventory": {"items": [PackedInt32Array([7, 10, 0]), Vector3i.ZERO, PackedInt32Array(), Vector3i.ZERO], "capacity": 2}}}}
    var path: String = manager._profile_path("fixture_host")
    var saved: Dictionary = manager.personal_store.save_checkpoint(path, state, 0, "fixture", "naraka", [], {})
    saved = manager.personal_store.transfer(path, saved["revision"], "a".repeat(64), "Inventory", 0, 0, 4, true, func(_id): return 64)
    check(saved.get("revision") == 2, "host deposit durable before restart")
    (await manager._restore_host_profile())
    check(manager.profile_revision == 2 and inventory.items[0].count == 6, "fresh host restores inventory and revision")
    check(manager.personal_store.read_profile(path)["chest"][0]["item"][1] == 4, "host chest survives restart")
    manager.save_queue = SlowQueue.new()
    var before_frames: int = frame_count
    save_in_background(manager)
    await get_tree().process_frame
    inventory.change_amount(0, -1)
    check(await manager._persist_host_profile() and background_done and manager.personal_store.read_profile(path)["state"]["node"]["player"]["Inventory"]["items"][0][1] == 5 and frame_count > before_frames + 2, "explicit checkpoint after slow autosave captures newer inventory while frames continue")
    inventory.change_amount(0, 1)
    await manager._persist_host_profile()
    var unchanged_bytes: PackedByteArray = manager.personal_store.files._read_bytes(manager.personal_store.storage_path(path))
    var unchanged_revision: int = manager.profile_revision
    check(await manager._persist_host_profile(true) and manager.profile_revision == unchanged_revision and manager.personal_store.files._read_bytes(manager.personal_store.storage_path(path)) == unchanged_bytes, "unchanged periodic checkpoint avoids revision and file rewrite")
    inventory.change_amount(0, -1)
    background_done = false
    save_in_background(manager)
    await get_tree().process_frame
    inventory.change_amount(0, -1)
    manager.save_queue.invalidate()
    while not background_done:
        await get_tree().process_frame
    check(await manager._persist_host_profile() and inventory.items[0].count == 4 and manager.personal_store.read_profile(path)["state"]["node"]["player"]["Inventory"]["items"][0][1] == 4, "hosting after an invalidated active save refreshes revision without rolling back live inventory")
    var old_loaded_file = Ref.save_file_manager.loaded_file
    Ref.save_file_manager.loaded_file = SaveFile.new()
    inventory.change_amount(0, -1)
    await manager._restore_host_profile()
    check(inventory.items[0].count == 4, "reloading the same world restores durable inventory into the new save object")
    Ref.save_file_manager.loaded_file = old_loaded_file
    await manager._restore_host_profile()
    inventory.change_amount(0, 2)
    await manager._persist_host_profile()
    var restore_player_mode: int = Ref.player.process_mode
    Ref.player.process_mode = Node.PROCESS_MODE_DISABLED
    var restore_disabled: bool = Ref.player.disabled
    Ref.player.disabled = false
    manager.restored_host_profile_path = ""
    background_done = false
    restore_in_background(manager)
    await get_tree().process_frame
    manager.save_queue.invalidate()
    while not background_done:
        await get_tree().process_frame
    check(not Ref.player.disabled and manager.restored_host_profile_path.is_empty(), "cancelled same-save restore cannot disable the current player")
    await manager._restore_host_profile()
    check(manager.restored_host_profile_path == path and inventory.items[0].count == 6, "same-save restoration waits behind the old operation and restores valid state")
    Ref.player.disabled = restore_disabled
    Ref.player.process_mode = restore_player_mode
    var unchanged_item = inventory.items[0]
    manager._apply_profile_inventories(manager._capture_local_persistent_state())
    check(inventory.items[0] == unchanged_item, "unchanged profile slots preserve held and equipped item instances")
    var pickup_baseline: Dictionary = manager._capture_local_persistent_state()
    var pickup_ack: Dictionary = pickup_baseline.duplicate(true)
    pickup_ack["node"]["player"]["Inventory"]["items"][2] = PackedInt32Array([7, 1, 0])
    inventory.change_amount(0, -1)
    var worn_item = inventory.items[0]
    manager._apply_profile_inventories(pickup_ack, pickup_baseline)
    check(inventory.items[0] == worn_item and inventory.items[0].count == 5 and inventory.items[1].count == 1, "pickup acknowledgement preserves unrelated live slot changes while adding loot")
    inventory.set_item(0, null)
    manager._apply_profile_inventories(pickup_ack, pickup_baseline)
    check(inventory.items[0] == null, "pickup acknowledgement cannot resurrect a tool broken after checkpoint")
    manager._apply_profile_inventories(pickup_baseline)
    var intent_disabled: bool = Ref.player.disabled
    Ref.player.coop_pending_drop = 0
    Ref.player.coop_pending_drop_item = inventory.items[0]
    Ref.player.coop_pending_interact = 0
    Ref.player.coop_pending_interact_item = inventory.items[0]
    Ref.player.disabled = true
    Ref.player.interaction_process({}, 0.0)
    check(Ref.player.coop_pending_drop == -1 and Ref.player.coop_pending_drop_item == null and Ref.player.coop_pending_interact == -1 and Ref.player.coop_pending_interact_item == null, "loading or disabled player clears deferred pickup action intent")
    Ref.player.disabled = intent_disabled
    manager.personal_store = preload("res://coop_mod/personal_store.gd").new()
    check((await manager._persist_host_profile()), "host can save after restart")
    var revision: int = manager.profile_revision
    manager.personal_store = FailedStore.new()
    check(not (await manager._persist_host_profile()) and manager.profile_revision == revision, "host write failure preserves revision")
    manager.personal_store = preload("res://coop_mod/personal_store.gd").new()
    check((await manager._persist_host_profile()) and manager.profile_revision == revision + 1, "host save recovers after failed write")
    var durable_before: PackedByteArray = manager.personal_store.files._read_bytes(manager.personal_store.storage_path(path))
    manager.guest_world_loaded = true
    manager.reconnect_pending = true
    check((await manager._persist_host_profile()) and manager.personal_store.files._read_bytes(manager.personal_store.storage_path(path)) == durable_before, "disconnected guest cache never writes a host profile")
    manager.guest_world_loaded = false
    manager.reconnect_pending = false
    manager.profile_commit_pending = true
    manager.profile_committed(0, false)
    check(not manager.profile_commit_pending and not manager.reconnect_reason_seen.is_empty(), "negative profile acknowledgement unlocks pending and requests safe reconnect")
    await manager._travel_group_to_dimension_async(3, false, false, "alice")
    check(manager.travelled == [[3, "alice"]], "legacy group caller reaches initiator-only loader")
    manager.pending_peer_teleport = 2
    manager.suppress_local_game_quit_session_shutdown = true
    manager._finish_pending_peer_teleport()
    check(manager.pending_peer_teleport == 2, "peer follow cannot finish before native dimension loading ends")
    manager.suppress_local_game_quit_session_shutdown = false
    manager.pending_peer_teleport = 0
    manager.terrain_epoch = "current"
    await manager._apply_canonical_terrain({"epoch": "old", "dimension_instance_key": manager.get_active_dimension_instance_key()})
    check(not manager.canonical_apply_busy, "old session terrain discarded before touching native world")
    await manager._apply_canonical_terrain({"epoch": "current", "dimension_instance_key": "pocket:alice"})
    check(not manager.canonical_apply_busy, "other dimension terrain discarded at application")
    var prior_file = Ref.save_file_manager.loaded_file
    Ref.save_file_manager.loaded_file = SaveFile.new()
    var access: String = manager._chest_access_key("naraka", Vector3i.ZERO)
    Ref.save_file_manager.loaded_file.set_data("coop/chest_access", {access: true}, true)
    manager.chest_sessions[1] = {"instance": "naraka", "position": Vector3i.ZERO}
    check(manager._valid_chest_session(1, "naraka", Vector3i.ZERO), "live designated access authorized")
    manager.peer_states[2] = {"active": false, "position": Vector3.ZERO, "dimension_instance_key": "naraka"}
    check(not manager._valid_chest_session(2, "naraka", Vector3i.ZERO), "inactive peer cannot authorize chest access")
    manager.peer_states[2]["active"] = true
    manager.peer_states[2]["downed"] = true
    check(not manager._valid_chest_session(2, "naraka", Vector3i.ZERO), "downed peer cannot authorize chest access")
    manager._remove_chest_access("naraka", Vector3i.ZERO)
    check(not manager._valid_chest_session(1, "naraka", Vector3i.ZERO) and manager.chest_sessions.is_empty(), "breaking access revokes sessions and replacement authorization")
    check(manager.personal_store.read_profile(path)["chest"][0]["item"][1] == 4, "breaking access preserves personal contents")
    if is_instance_valid(Ref.player) and is_instance_valid(Ref.game_menu):
        var access_block := AccessBlock.new()
        add_child(access_block)
        access_block.global_position = Ref.player.global_position
        var panel = preload("res://coop_mod/personal_chest.gd").new()
        add_child(panel)
        panel.start(manager, access_block)
        panel.receive(manager.personal_store.read_profile(path), "fixture_token")
        check(panel.slots.get_child_count() == 21, "real chest panel builds21 selectable slots")
        panel.slots.get_child(3).pressed.emit()
        var row = panel.rows.get_child(0)
        row.get_child(1).pressed.emit()
        await get_tree().process_frame
        await get_tree().process_frame
        check(manager.transfers.size() == 1 and manager.transfers[0][4] == 3 and manager.transfers[0][5] == 1 and manager.transfers[0][6], "panel routes selected slot and quantity to transaction command")
        check(is_instance_valid(panel), "live player chest remains open after transfer request")
        if is_instance_valid(panel):
            panel.queue_free()
        await get_tree().process_frame
        await get_tree().process_frame
        access_block.free()
        var original_disabled: bool = Ref.player.disabled
        manager.begin_chest_inventory_lock(false)
        check(not manager._is_client_gameplay_locked() and manager.chest_lock_active, "pickup protects inventory without locking attacks mining or hotbar")
        manager._release_chest_inventory_lock()
        manager.begin_chest_inventory_lock()
        manager.chest_pending_token = "pending_fixture"
        manager.chest_active_token = "pending_fixture"
        manager._queue_or_apply_received_pickup(PackedInt32Array([7, 1, 0]))
        manager.close_personal_chest("pending_fixture")
        check(manager.chest_lock_active and Ref.player.disabled == original_disabled and manager.pickup_inventory_counts.is_empty(), "closing pending chest restores movement while retaining inventory lock")
        manager.receive_personal_chest(manager.personal_store.read_profile(path), "wrong_token")
        check(manager.chest_pending_token == "pending_fixture", "late unrelated chest acknowledgement ignored")
        manager.receive_personal_chest(manager.personal_store.read_profile(path), "pending_fixture")
        check(not manager.chest_lock_active and manager.pickup_inventory_counts == [6] and manager.chest_queued_pickups.is_empty(), "matching acknowledgement restores inventory before exactly one queued pickup")
        manager.receive_personal_chest(manager.personal_store.read_profile(path), "pending_fixture")
        check(manager.pickup_inventory_counts == [6], "duplicate acknowledgement cannot replay queued pickup")
        manager.begin_chest_inventory_lock()
        manager.chest_pending_token = "timeout_fixture"
        manager.chest_request_sent_at = 0
        manager._queue_or_apply_received_pickup(PackedInt32Array([7, 1, 0]))
        manager._tick_chest_transaction_timeout(6000)
        check(manager.chest_pending_token == "recovering" and manager.chest_lock_active and manager.chest_queued_pickups.size() == 1 and manager.reconnect_reason_seen.contains("Chest transaction"), "lost acknowledgement requests durable reconnect without releasing stale inventory")
        manager._apply_profile_inventories(manager.personal_store.read_profile(path)["state"])
        manager.chest_pending_token = ""
        manager._release_chest_inventory_lock()
        check(not manager.chest_lock_active and manager.pickup_inventory_counts == [6, 6], "authoritative recovery releases queued pickup once after inventory restore")
        Ref.player.disabled = original_disabled
        var closed_peer := ENetMultiplayerPeer.new()
        var closed_api := SceneMultiplayer.new()
        var created: bool = closed_peer.create_server(0, 1) == OK
        check(created, "closed transport cleanup fixture binds ephemeral peer")
        if created:
            get_tree().set_multiplayer(closed_api, manager.get_path())
            closed_api.multiplayer_peer = closed_peer
            closed_peer.close()
            manager.begin_chest_inventory_lock()
            manager.chest_active_token = "disconnected_fixture"
            manager.chest_sessions[1] = {"token": "disconnected_fixture"}
            manager._invalidate_local_chest()
            check(closed_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED and manager.chest_active_token.is_empty() and manager.chest_sessions.is_empty() and not manager.chest_lock_active and Ref.player.disabled == original_disabled, "inactive ENet invalidation clears chest and releases lock without querying server identity")
            closed_api.multiplayer_peer = OfflineMultiplayerPeer.new()
            get_tree().set_multiplayer(null, manager.get_path())
    else:
        check(false, "chest UI runtime prerequisites exist")
    Ref.save_file_manager.loaded_file = prior_file
    Ref.player_inventory = previous[0]
    Ref.player_hotbar = previous[1]
    Ref.player_equipment = previous[2]
    Ref.player_fusion_source = previous[3]
    Ref.player_fusion_result = previous[4]
    Ref.player.dead = original_dead
    Ref.player.process_mode = original_player_mode
    manager.free()
    inventory.free()
    print("PROFILE_RUNTIME_RESULT ", checks, " checks ", failures, " failures")
    return failures
