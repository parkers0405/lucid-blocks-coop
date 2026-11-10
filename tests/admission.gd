extends Node


class PeerFixture extends "res://coop_mod/coop_manager.gd":
    var hello_override: Dictionary = {}
    var silent_auth: bool = false
    var admitted_count: int = 0
    var snapshot_requests: int = 0
    var failed_count: int = 0
    var accepted_profile_keys: Array = []

    func _has_legacy_player_identities() -> bool:
        return false

    func _identity_scope() -> String:
        return "fixture-world".sha256_text()

    func _identity_host_path() -> String:
        return "user://admission/host.json"

    func _identity_client_path() -> String:
        return "user://admission/client.json"

    func _get_local_player_key() -> String:
        return authenticated_local_key if not authenticated_local_key.is_empty() else "fixture_host"

    func _store_guest_persistent_state(key: String, _name: String, _state: Dictionary) -> void:
        accepted_profile_keys.append(key)

    func _ready() -> void:
        pass

    func _physics_process(_delta: float) -> void:
        pass

    func _compatibility_hello() -> Dictionary:
        var message: Dictionary = super._compatibility_hello()
        message.merge(hello_override, true)
        return message

    func _on_peer_authenticating(id: int) -> void:
        if silent_auth:
            auth_pending[id] = false
        else:
            super._on_peer_authenticating(id)

    func _on_peer_connected(id: int) -> void:
        auth_pending.erase(id)
        admitted_count += 1

    func _on_peer_disconnected(id: int) -> void:
        admitted_player_keys.erase(id)
        identity_challenges.erase(id)
        auth_pending.erase(id)

    func _on_connected_to_server() -> void:
        snapshot_requests += 1

    func _finish_compatibility_failure(reason: String) -> void:
        status_message = reason
        failed_count += 1

    func _update_status_text() -> void:
        pass


var assertions: int = 0
var failures: int = 0
var branches: Array[Node] = []


func _assert(condition: bool, message: String) -> void:
    assertions += 1
    if not condition:
        failures += 1
        print("ADMISSION_FAIL ", message)


func _wait_until(predicate: Callable, timeout_msec: int = 2000) -> bool:
    var deadline: int = Time.get_ticks_msec() + timeout_msec
    while not predicate.call() and Time.get_ticks_msec() < deadline:
        for branch in branches:
            branch.get_node("Manager").multiplayer.poll()
        await get_tree().process_frame
    return bool(predicate.call())


func _peer(name_value: String, transport: ENetMultiplayerPeer, override: Dictionary = {}, silent: bool = false) -> PeerFixture:
    var branch := Node.new()
    branch.name = name_value
    add_child(branch)
    branches.append(branch)
    var api := SceneMultiplayer.new()
    get_tree().set_multiplayer(api, branch.get_path())
    var fixture := PeerFixture.new()
    fixture.name = "Manager"
    fixture.hello_override = override
    fixture.silent_auth = silent
    branch.add_child(fixture)
    api.peer_connected.connect(fixture._on_peer_connected)
    api.peer_disconnected.connect(fixture._on_peer_disconnected)
    api.connected_to_server.connect(fixture._on_connected_to_server)
    fixture._assign_session_peer(transport)
    api.auth_timeout = 0.25
    return fixture


func _close_peers() -> void:
    for branch in branches:
        var fixture = branch.get_node("Manager")
        fixture.multiplayer.multiplayer_peer.close()
        fixture.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
        get_tree().set_multiplayer(null, branch.get_path())
        branch.queue_free()
    branches.clear()
    await get_tree().process_frame


func _pair(override: Dictionary = {}, silent: bool = false) -> Array:
    var server := ENetMultiplayerPeer.new()
    server.set_bind_ip("127.0.0.1")
    _assert(server.create_server(0, 1) == OK, "create loopback server")
    var host := _peer("Host", server)
    var client := ENetMultiplayerPeer.new()
    _assert(client.create_client("127.0.0.1", server.get_host().get_local_port()) == OK, "create loopback client")
    var guest := _peer("Guest", client, override, silent)
    _assert(host.multiplayer != guest.multiplayer, "isolated multiplayer APIs")
    return [host, guest]


func run() -> int:
    var identities = preload("res://coop_mod/session_identity.gd").new()
    var record_path: String = "user://admission/data.json"
    var issued: Dictionary = identities.admit(record_path, "", 0, [])
    _assert(not issued.is_empty(), "durable LAN credential issued")
    _assert(identities.admit(record_path, issued["token"], 0, [issued["key"]]).is_empty(), "duplicate active identity refused")
    _assert(identities.admit(record_path, "f".repeat(64), 0, []).is_empty(), "unknown credential refused")
    _assert(identities.admit(record_path, issued["token"], 0, [])["key"] == issued["key"], "identity survives store reload")
    _assert(not FileAccess.get_file_as_string(record_path).contains(issued["token"]), "host stores credential digest only")
    _assert(identities.admit(record_path, "", 12345, [])["key"] == "steam_12345", "transport Steam identity used")
    identities.write_record(record_path, {"identities": {issued["token"].sha256_text(): 123}})
    _assert(identities.admit(record_path, issued["token"], 0, []).is_empty(), "malformed mapping value fails closed")
    identities.write_record(record_path, {"identities": false})
    _assert(identities.admit(record_path, "", 0, []).is_empty(), "corrupt identity store fails closed")
    for method in ClassDB.class_get_method_list("SteamMultiplayerPeer", true) if ClassDB.class_exists("SteamMultiplayerPeer") else []:
        if "steam" in str(method["name"]).to_lower() and "peer" in str(method["name"]).to_lower():
            print("IDENTITY_TRANSPORT_METHOD ", method["name"])
    var validation := PeerFixture.new()
    validation.auth_session_nonce = "0123456789abcdef0123456789abcdef"
    var hello: Dictionary = JSON.parse_string(JSON.stringify(validation._compatibility_hello()))
    _assert(validation._compatibility_error(hello).is_empty(), "matching serialized hello")
    _assert(hello["game"] == "5.2.0" and hello["native"] == "vanilla-5.2.0", "installed5.2 target pinned explicitly")
    var prior_build: Dictionary = hello.duplicate()
    prior_build["game"] = "5.1.0"
    _assert(validation._compatibility_error(prior_build) == "game", "previous game build remains rejected")
    var updated_creature = load("res://main/entity/bubblebear/hwobbb.gd") as GDScript
    _assert(updated_creature != null and updated_creature.can_instantiate(), "new5.2 creature inherits compatible bubblebear state")
    for case in [
        [{"game": "0.0.0"}, "game"],
        [{"game": 1}, "game"],
        [{"protocol": 999}, "protocol"],
        [{"protocol": 3}, "protocol"],
        [{"protocol": 4}, "protocol"],
        [{"protocol": "1"}, "protocol"],
        [{"players": 4}, "full"],
        [{"players": "2"}, "full"],
        [{"native": "unvalidated"}, "native"],
        [{"native": 1}, "native"],
        [{"nonce": "invalid"}, "malformed"],
        [{"nonce": {}}, "malformed"],
        [{"extra": true}, "malformed"],
    ]:
        var message: Dictionary = hello.duplicate()
        message.merge(case[0], true)
        _assert(validation._compatibility_error(message) == case[1], "invalid hello field rejected: %s expected %s" % [str(case[0].keys()), case[1]])
    _assert(validation._compatibility_error({}) == "malformed", "empty hello rejected")
    validation.free()
    print("ADMISSION_DATA_RESULT assertions=", assertions, " failures=", failures)
    print("ADMISSION_CASE matching and slot reuse")
    var manager_script = load("res://coop_mod/coop_manager.gd")
    _assert(manager_script.MAX_PLAYERS == 2 and manager_script.MAX_CLIENTS == 1, "two-player transport limits")
    var pair: Array = _pair()
    var host: PeerFixture = pair[0]
    var guest: PeerFixture = pair[1]
    _assert(guest.snapshot_requests == 0 and guest.multiplayer.get_peers().is_empty(), "no snapshots before authentication")
    _assert(await _wait_until(func(): return host.admitted_count == 1 and guest.snapshot_requests == 1), "matching peers admitted")
    _assert(host.auth_pending.is_empty(), "admission releases pending slot")
    var original_key: String = guest.authenticated_local_key
    _assert(original_key.begins_with("lan_") and host.admitted_player_keys.values().has(original_key), "host-issued identity bound to sender")
    guest.submit_guest_persistent_state.rpc_id(1, "steam_forged", "guest", {"fixture": true})
    await _wait_until(func(): return false, 50)
    _assert(host.accepted_profile_keys.is_empty(), "forged profile identity rejected by actual RPC")
    guest.submit_guest_persistent_state.rpc_id(1, original_key, "guest", {"fixture": true})
    _assert(await _wait_until(func(): return host.accepted_profile_keys == [original_key]), "authenticated profile RPC reaches only bound identity")
    var revision_key: String = preload("res://coop_mod/chunk_authority.gd").chunk_key("naraka", Vector3i.ZERO)
    host.begin_host_world_snapshot.rpc_id(guest.multiplayer.get_unique_id(), "{}", 1, Vector3.ZERO, {revision_key: 7}, host.terrain_epoch, false)
    _assert(await _wait_until(func(): return guest.chunk_authority.revisions.get(revision_key) == 7), "snapshot seeds existing chunk revisions before returning player edits")
    var proposed_root: Dictionary = {"test_chunk_block": {Vector3i.ZERO: PackedInt32Array([1])}}
    _assert(guest.chunk_authority.current("naraka", proposed_root, "test_", guest.chunk_authority.revisions), "first post-reconnect checkpoint uses seeded revision")
    guest.receiving_host_world = false
    var third_transport := ENetMultiplayerPeer.new()
    third_transport.create_client("127.0.0.1", host.multiplayer.multiplayer_peer.get_host().get_local_port())
    var third := _peer("Third", third_transport)
    await get_tree().create_timer(0.15).timeout
    _assert(third.admitted_count == 0 and third.snapshot_requests == 0 and host.multiplayer.get_peers().size() == 1, "third participant never admitted")
    third_transport.close()
    third.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    guest.multiplayer.multiplayer_peer.close()
    _assert(await _wait_until(func(): return host.multiplayer.get_peers().is_empty()), "disconnect releases slot")
    var replacement_transport := ENetMultiplayerPeer.new()
    replacement_transport.create_client("127.0.0.1", host.multiplayer.multiplayer_peer.get_host().get_local_port())
    var replacement := _peer("Replacement", replacement_transport)
    _assert(await _wait_until(func(): return replacement.snapshot_requests == 1), "guest rejoins released slot")
    _assert(replacement.authenticated_local_key == original_key, "reconnect restores identity with a new peer id")
    await _close_peers()
    # The validation table covers every field; one wire rejection proves disconnect behavior.
    for mismatch in [{"protocol": 999}]:
        print("ADMISSION_CASE mismatch ", mismatch.keys())
        pair = _pair(mismatch)
        host = pair[0]
        guest = pair[1]
        _assert(await _wait_until(func(): return guest.failed_count > 0), "mismatch rejected with a reason")
        _assert(host.admitted_count == 0 and guest.snapshot_requests == 0, "mismatch sends no snapshots")
        _assert(not guest.status_message.is_empty(), "mismatch reason available to UI")
        await _close_peers()
    print("ADMISSION_CASE timeout")
    pair = _pair({}, true)
    host = pair[0]
    guest = pair[1]
    _assert(await _wait_until(func(): return guest.failed_count > 0), "silent peer times out")
    _assert(host.admitted_count == 0 and guest.snapshot_requests == 0, "timeout sends no snapshots")
    _assert("timed out" in guest.status_message, "timeout reason available to UI")
    await _close_peers()
    print("ADMISSION_RESULT assertions=", assertions, " failures=", failures)
    return failures
