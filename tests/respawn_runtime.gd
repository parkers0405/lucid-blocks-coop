extends Node
const Store = preload("res://coop_mod/personal_store.gd")
class Manager extends "res://coop_mod/coop_manager.gd":
    var fixture_root: String
    var live: bool = true
    var instance: String = "pocket:alice"
    var resident: Array = []
    var sent: Array = []
    var can_sample: bool = true
    func _ready() -> void:
        pass
    func _physics_process(_delta: float) -> void:
        pass
    func _get_local_player_key() -> String:
        return "host"
    func _can_sample_player() -> bool:
        return can_sample
    func _can_share_loaded_world() -> bool:
        return true
    func _has_live_peer() -> bool:
        return live
    func _get_checkpoint_chunks_directory() -> String:
        return fixture_root.path_join("chunks")
    func get_active_dimension_instance_key() -> String:
        return instance
    func _local_loaded_lease_chunks() -> Array:
        return resident.duplicate()
    func _respawn_chunk_is_resident(chunk: Vector3i) -> bool:
        return resident.has(chunk)
    func _send_private_respawns(key: String, positions: Dictionary, chunks: Array) -> void:
        sent.append({"instance": key, "positions": positions.duplicate(true), "chunks": chunks.duplicate()})
    func _update_status_text() -> void:
        pass
class FixtureWorld extends "res://main/world/world.gd":
    var fixture_manager: Node
    func _respawn_manager():
        return fixture_manager
class FailedStore extends "res://coop_mod/personal_store.gd":
    func _write_ledger(_path: String, _ledger: Dictionary) -> bool:
        return false
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("RESPAWN_RUNTIME_FAIL ", label)
func state(revision: int, positions: Dictionary, chunks: Array) -> Dictionary:
    return {"_coop_revision": revision, "node": {"player": {"marker": "profile"}}, "_coop_respawns": {"positions": positions, "chunks": chunks}}
func run() -> int:
    check(Store.respawn_chunk(Vector3i(-1, 0, 0)) == Vector3i(-16, 0, 0), "negative respawn coordinates snap down")
    check(not Store.valid_respawns({Vector3i.ZERO: false}) and not Store.valid_respawns({Vector3i.ZERO: 1}) and not Store.valid_respawns({Vector3.ZERO: true}), "respawn maps reject invalid values and coordinate types")
    check(not Store.valid_respawn_update({"positions": {}, "chunks": [Vector3i.ZERO, Vector3i.ZERO]}) and not Store.valid_respawn_update({"positions": {}, "chunks": [Vector3i.ONE]}), "coverage rejects duplicate and unsnapped chunks")
    var excessive: Dictionary = {}
    for index in range(Store.MAX_RESPAWNS + 1):
        excessive[Vector3i(index, 0, 0)] = true
    check(not Store.valid_respawns(excessive), "respawn count stays bounded")
    check(not Store.valid_respawn_update({"positions": {Vector3i(32, 0, 0): true}, "chunks": [Vector3i.ZERO]}), "respawn update cannot escape declared coverage")
    var manager := Manager.new()
    manager.fixture_root = "user://respawn_runtime_" + Crypto.new().generate_random_bytes(8).hex_encode()
    add_child(manager)
    var previous_dimension: int = int(Ref.world.current_dimension)
    var previous_respawns: Dictionary[Vector3i, bool] = Ref.world.respawn_positions.duplicate(true)
    var previous_register = Ref.save_file_manager.loaded_file_register
    var previous_file = Ref.save_file_manager.loaded_file
    var register := SaveFileRegister.new()
    register.is_dimensional = false
    register.set_data("pocket_owner_key", "alice", true)
    Ref.save_file_manager.loaded_file_register = register
    Ref.save_file_manager.loaded_file = SaveFile.new()
    Ref.world.current_dimension = 3
    var a := Vector3i(1, 2, 3)
    var b := Vector3i(33, 2, 3)
    var c := Vector3i(65, 2, 3)
    var ca: Vector3i = Store.respawn_chunk(a)
    var cb: Vector3i = Store.respawn_chunk(b)
    var cc: Vector3i = Store.respawn_chunk(c)
    manager.resident = [ca, cb, cc]
    manager.chunk_authority.lease_owners = {manager.ChunkAuthority.chunk_key("pocket:alice", ca): 1, manager.ChunkAuthority.chunk_key("pocket:alice", cb): 2}
    Ref.world.respawn_positions.assign({a: true, b: true, c: true})
    var captured: Dictionary = manager._capture_private_respawns()
    check(captured == {"positions": {a: true}, "chunks": [ca]}, "capture includes explicit resident host grant only")
    var host_path: String = manager._profile_path("host")
    var guest_path: String = manager._profile_path("guest")
    var host: Dictionary = manager._commit_player_checkpoint("host", state(0, captured["positions"], captured["chunks"]), "pocket:alice", 3, [])
    check(host.get("revision") == 1 and not host["state"].has("_coop_respawns"), "private map commits atomically and is stripped from player profile")
    var guest: Dictionary = manager._commit_player_checkpoint("guest", state(0, {b: true}, [cb]), "pocket:alice", 3, [])
    check(guest.get("revision") == 1 and manager.personal_store.instance_respawns(host_path, "pocket__alice")["positions"] == {a: true, b: true}, "authenticated visitor metadata merges disjoint same-instance coverage")
    check(manager.sent.size() == 2 and manager.sent[1]["positions"] == {b: true} and manager.sent[1]["chunks"] == [cb], "live metadata publication is scoped to committing actor coverage")
    manager.lease_frozen = true
    manager.can_sample = false
    manager.terrain_epoch = "respawn-handoff"
    Ref.world.respawn_positions.erase(b)
    var install: Dictionary = {"dimension_instance_key": "pocket:alice", "epoch": manager.terrain_epoch, "private_respawns": {"positions": {b: true}, "chunks": [cb]}}
    check(manager._install_lease_respawns(install) and Ref.world.respawn_positions.has(b), "lease installation refreshes newly granted map while sampling is frozen before resume")
    install["epoch"] = "stale"
    check(not manager._install_lease_respawns(install), "old epoch cannot replace lease respawn map")
    install["epoch"] = manager.terrain_epoch
    install["private_respawns"]["positions"] = {a: true}
    check(not manager._install_lease_respawns(install) and Ref.world.respawn_positions.has(b), "lease metadata outside declared coverage is rejected without mutation")
    manager.can_sample = true
    manager.chunk_authority.lease_owners[manager.ChunkAuthority.chunk_key("pocket:alice", cb)] = 1
    check(manager._capture_private_respawns()["positions"].has(b), "first newly granted capture retains canonical partner respawn")
    manager.chunk_authority.lease_owners[manager.ChunkAuthority.chunk_key("pocket:alice", cb)] = 2
    manager.lease_frozen = false
    host = manager._commit_player_checkpoint("host", state(1, {}, [ca]), "pocket:alice", 3, [])
    check(host.get("revision") == 2 and manager.personal_store.instance_respawns(host_path, "pocket__alice")["positions"] == {b: true} and Ref.world.respawn_positions == {b: true, c: true}, "owner deletion preserves visitor and unobserved live points")
    var before: PackedByteArray = manager.personal_store.files._read_bytes(Store.storage_path(host_path))
    check(manager._commit_player_checkpoint("host", state(2, {c: true}, [cc]), "pocket:alice", 3, []).is_empty() and manager.personal_store.files._read_bytes(Store.storage_path(host_path)) == before, "default-host unknown chunk is not metadata deletion authority")
    check(manager._commit_player_checkpoint("guest", state(1, {a: true}, [ca]), "pocket:alice", 3, []).is_empty(), "visitor cannot claim host leased chunk")
    manager.resident.erase(ca)
    check(manager._commit_player_checkpoint("host", state(2, {}, [ca]), "pocket:alice", 3, []).is_empty(), "host grant without current residency cannot delete metadata")
    manager.resident.append(ca)
    guest = manager._commit_player_checkpoint("guest", state(1, {}, [cb]), "pocket:alice", 3, [])
    check(guest.get("revision") == 2 and manager.personal_store.instance_respawns(host_path, "pocket__alice")["present"] and manager.personal_store.instance_respawns(host_path, "pocket__alice")["positions"].is_empty(), "last covered deletion preserves intentional empty map")
    manager.admitted_player_keys[2] = "guest"
    manager.peer_states[2] = {"dimension": 3, "pocket_owner_key": "alice", "dimension_instance_key": "pocket:alice", "player_key": "guest", "active": true}
    var character: Dictionary = state(2, {}, [cb])
    character["_coop_dimension"] = 3
    character["_coop_owner"] = "alice"
    character["_coop_lease_epoch"] = manager.chunk_authority.lease_epoch
    character["pocket__guest"] = {"respawn_positions": {c: true}}
    character["pocket__guest_world"] = {"pocket__guest_chunk_block": {}, "pocket__guest_chunk_water": {}, "pocket__guest_chunk_water_awake": {}, "pocket__guest_chunk_fire": {}}
    manager._store_guest_persistent_state("guest", "Guest fixture", character)
    check(not Ref.save_file_manager.loaded_file.data.has("pocket__guest_world") and SaveFile._get_data(Ref.save_file_manager.loaded_file.data, "pocket__guest/respawn_positions", null) == null and not manager.personal_store.read_profile(guest_path)["state"].has("_coop_respawns"), "character packet cannot publish namespace world metadata around covered checkpoint")
    var stale: Dictionary = {"pocket__alice": {"respawn_positions": {a: true}}, "pocket": {"respawn_positions": {b: true}}}
    var read: Dictionary = manager.read_private_respawns(stale, 3, "alice")
    check(read["present"] and read["positions"].is_empty(), "canonical empty wins over stale root and plain legacy sources")
    var only_plain: Dictionary = {"pocket": {"respawn_positions": {a: true}}}
    read = manager.read_private_respawns(only_plain, 3, "bob", "alice")
    check(read["ok"] and not read["present"], "foreign unqualified private map is never adopted")
    var fresh_snapshot: Dictionary = only_plain.duplicate(true)
    check(manager._merge_instance_nodes_into_snapshot(fresh_snapshot, "pocket:host", 3, "host", "foreign") and SaveFile._get_data(fresh_snapshot, "pocket__host/respawn_positions", null) == {} and fresh_snapshot["pocket"]["respawn_positions"] == {a: true}, "fresh target snapshot qualifies empty map without importing or deleting foreign plain source")
    var explicit_root: Dictionary = {"pocket__bob": {"respawn_positions": {c: true}}, "pocket": {"pocket__bob": {"respawn_positions": {b: true}}, "respawn_positions": {a: true}}}
    read = manager.read_private_respawns(explicit_root, 3, "bob", "alice")
    check(read["positions"] == {c: true}, "target root source takes precedence over old double prefix")
    explicit_root.erase("pocket__bob")
    var source_before: Dictionary = explicit_root.duplicate(true)
    read = manager.read_private_respawns(explicit_root, 3, "bob", "alice")
    check(read["positions"] == {b: true} and explicit_root == source_before, "old plain owner-prefix source is readable and retained")
    check(not manager.read_private_respawns({"pocket__bob": {"respawn_positions": {b: false}}}, 3, "bob")["ok"], "invalid owner map fails load validation")
    var cache_before: Dictionary = Ref.save_file_manager.loaded_file.data.duplicate(true)
    var live_before: Dictionary = Ref.world.respawn_positions.duplicate(true)
    manager.personal_store = FailedStore.new()
    check(manager._commit_player_checkpoint("host", state(2, {a: true}, [ca]), "pocket:alice", 3, []).is_empty() and Ref.save_file_manager.loaded_file.data == cache_before and Ref.world.respawn_positions == live_before, "failed metadata checkpoint changes neither active map nor save cache")
    manager.personal_store = Store.new()
    manager._merge_world_patch_into_cache({"dimension": 3, "pocket_owner_key": "alice", "respawn_positions": {c: true}, "world_data": {}})
    check(Ref.save_file_manager.loaded_file.data == cache_before, "old unscoped private terrain patch cannot replace metadata")
    var solo := Manager.new()
    solo.fixture_root = "user://respawn_solo_" + Crypto.new().generate_random_bytes(8).hex_encode()
    solo.live = false
    solo.instance = "pocket:host"
    add_child(solo)
    read = solo.read_private_respawns(only_plain, 3, "host", "")
    check(read["present"] and read["positions"] == {a: true}, "proven original solo source permits local plain adoption")
    check(not solo.read_private_respawns(only_plain, 3, "host", "foreign")["present"], "foreign source owner blocks plain adoption")
    solo.free()
    var firmament: int = int(Ref.world.Dimension.FIRMAMENT)
    var firm_instance: String = manager.get_dimension_instance_key(firmament, "alice")
    var firm_namespace: String = manager._resolve_dimension_namespace(firmament, "alice")
    var profile: Dictionary = manager.personal_store.read_profile(host_path)
    manager.personal_store.save_checkpoint(host_path, profile["state"], profile["revision"], manager._ledger_instance_key(firm_instance), SaveFile.DIMENSION_MAP[firmament], [], {}, {"positions": {c: true}, "chunks": [cc]})
    var wipe := SaveFile.new()
    wipe.data = {firm_namespace: {"respawn_positions": {c: true}}, SaveFile.DIMENSION_MAP[firmament]: {firm_namespace: {"respawn_positions": {a: true}}}}
    wipe.clear_dimension_data(firmament)
    check(not wipe.data.has(firm_namespace), "actual base FIRMAMENT reset clears owner root metadata")
    var restarted := Manager.new()
    restarted.fixture_root = manager.fixture_root
    restarted.live = false
    add_child(restarted)
    check(restarted.prepare_instance_preserved_state(wipe, firmament, "alice", "") and SaveFile._get_data(wipe.data, firm_namespace + "/respawn_positions", {}) == {c: true}, "ledger restores owner map before world load after reset and restart")
    var world := FixtureWorld.new()
    world.fixture_manager = restarted
    world.current_dimension = firmament
    world.load_file(wipe)
    check(world.respawn_positions == {c: true}, "actual private World.load_file restores canonical owner map")
    var saved := SaveFile.new()
    world.save_file(saved)
    check(SaveFile._get_data(saved.data, firm_namespace + "/respawn_positions", {}) == {c: true} and not saved.data.has("pocket"), "actual private World.save_file uses root owner path without dimensional double prefix")
    register.set_data("pocket_owner_key", "host", true)
    world.current_dimension = 3
    var foreign_load := SaveFile.new()
    foreign_load.data = only_plain.duplicate(true)
    world.load_file(foreign_load)
    check(world.respawn_positions.is_empty() and foreign_load.data == only_plain, "destination register alone cannot authorize private plain-map fallback")
    Ref.world.current_dimension = 2
    world.current_dimension = 2
    world.respawn_positions.assign({a: true})
    var public_file := SaveFile.new()
    world.save_file(public_file)
    SaveFile._set_data(public_file.data, "naraka/respawn_positions", {a: true})
    var empty_positions: Dictionary[Vector3i, bool] = {}
    world.respawn_positions = empty_positions
    world.load_file(public_file)
    check(world.respawn_positions == {a: true} and SaveFile._get_data(public_file.data, "naraka/respawn_positions", {}) == {a: true}, "public save and load retain native dimensional path")
    Ref.world.current_dimension = 3
    world.current_dimension = 3
    register.set_data("pocket_owner_key", "", true)
    var ownerless := SaveFile.new()
    ownerless.data = only_plain.duplicate(true)
    world.load_file(ownerless)
    check(world.respawn_positions == {a: true}, "ownerless solo private load retains native plain path")
    world.free()
    var corrupt: Dictionary = manager.personal_store.read_ledger(host_path)
    corrupt["instances"]["pocket__alice"]["respawn_positions"][a] = false
    manager.personal_store.files._replace_file(Store.storage_path(host_path), var_to_bytes(corrupt))
    check(manager.personal_store.read_ledger(host_path).is_empty(), "corrupt persisted metadata fails the shared ledger closed")
    restarted.free()
    manager.free()
    Ref.world.current_dimension = previous_dimension
    Ref.world.respawn_positions.assign(previous_respawns)
    Ref.save_file_manager.loaded_file_register = previous_register
    Ref.save_file_manager.loaded_file = previous_file
    print("RESPAWN_RUNTIME_RESULT ", checks, " checks ", failures, " failures")
    return failures
