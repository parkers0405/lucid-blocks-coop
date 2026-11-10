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

class AccessBlock extends Node3D:
    var broken: bool = false

class FailedStore extends "res://coop_mod/personal_store.gd":
    func _write_ledger(_path: String, _record: Dictionary) -> bool:
        return false

var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("PROFILE_RUNTIME_FAIL ", label)

func run() -> int:
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
    var saved: Dictionary = manager.personal_store.save_state(path, state, 0)
    saved = manager.personal_store.transfer(path, saved["revision"], "a".repeat(64), "Inventory", 0, 0, 4, true, func(_id): return 64)
    check(saved.get("revision") == 2, "host deposit durable before restart")
    manager._restore_host_profile()
    check(manager.profile_revision == 2 and inventory.items[0].count == 6, "fresh host restores inventory and revision")
    check(manager.personal_store.read_profile(path)["chest"][0]["item"][1] == 4, "host chest survives restart")
    check(manager._persist_host_profile(), "host can save after restart")
    var revision: int = manager.profile_revision
    manager.personal_store = FailedStore.new()
    check(not manager._persist_host_profile() and manager.profile_revision == revision, "host write failure preserves revision")
    manager.personal_store = preload("res://coop_mod/personal_store.gd").new()
    check(manager._persist_host_profile() and manager.profile_revision == revision + 1, "host save recovers after failed write")
    var durable_before: PackedByteArray = manager.personal_store.files._read_bytes(manager.personal_store.storage_path(path))
    manager.guest_world_loaded = true
    manager.reconnect_pending = true
    check(manager._persist_host_profile() and manager.personal_store.files._read_bytes(manager.personal_store.storage_path(path)) == durable_before, "disconnected guest cache never writes a host profile")
    manager.guest_world_loaded = false
    manager.reconnect_pending = false
    manager.profile_commit_pending = true
    manager.profile_committed(0, false)
    check(not manager.profile_commit_pending and not manager.reconnect_reason_seen.is_empty(), "negative profile acknowledgement unlocks pending and requests safe reconnect")
    await manager._travel_group_to_dimension_async(3, false, false, "alice")
    check(manager.travelled == [[3, "alice"]], "legacy group caller reaches initiator-only loader")
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
        panel.free()
        access_block.free()
        var original_disabled: bool = Ref.player.disabled
        manager.begin_chest_inventory_lock()
        manager.chest_pending_token = "pending_fixture"
        manager.chest_active_token = "pending_fixture"
        manager._queue_or_apply_received_pickup(PackedInt32Array([7, 1, 0]))
        manager.close_personal_chest("pending_fixture")
        check(manager.chest_lock_active and Ref.player.disabled and manager.pickup_inventory_counts.is_empty(), "forced panel close keeps pending inventory lock and queued pickup")
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
    manager.free()
    inventory.free()
    print("PROFILE_RUNTIME_RESULT ", checks, " checks ", failures, " failures")
    return failures
