extends Node

const Store = preload("res://coop_mod/personal_store.gd")
const SCENE: String = "res://main/entity/gel/gel.tscn"
const UUID_A: String = "11111111-1111-4111-8111-111111111111"
const UUID_B: String = "22222222-2222-4222-8222-222222222222"

class Manager extends "res://coop_mod/coop_manager.gd":
    var fixture_root: String
    func _ready() -> void:
        pass
    func _physics_process(_delta: float) -> void:
        pass
    func _get_local_player_key() -> String:
        return "host"
    func _get_checkpoint_chunks_directory() -> String:
        return fixture_root.path_join("chunks")
    func _can_share_loaded_world() -> bool:
        return true
    func get_active_dimension_instance_key() -> String:
        return "dimension:2"
    func _capture_local_state() -> Dictionary:
        return {"dimension_instance_key": "dimension:2", "position": Vector3.ZERO, "active": true}
    func _preserved_scene_paths() -> Dictionary:
        return {SCENE: true}
    func _update_status_text() -> void:
        pass

class FailedFiles extends "res://coop_mod/region_checkpoint.gd":
    func _replace_file(_path: String, _bytes: PackedByteArray) -> bool:
        return false

class PreserveFixture extends "res://main/save_file/preserve_node_manager.gd":
    func _is_guest_replica_mode() -> bool:
        return false

var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("INSTANCE_NODES_FAIL ", label)

func bundle(uuid: String, dimension: String) -> Dictionary:
    return {"uuid": uuid, "scene_path": SCENE, "position": Vector3.ZERO, "save_data": {dimension: {"node": {uuid: {"global_position": Vector3.ZERO, "health": 10, "file_path": SCENE}}}}}

func run() -> int:
    var preserve := PreserveFixture.new()
    var fresh := SaveFile.new()
    fresh.is_dimensional = false
    fresh.data = {"world": {"chunk_to_uuid_map": {}}}
    preserve.load_file(fresh)
    check(preserve.chunk_to_uuid_map.is_empty() and preserve.chunk_to_uuid_map.is_typed(), "fresh generic empty map restores typed preservation index")
    fresh.data = {"world": {"chunk_to_uuid_map": {Vector3i.ZERO: PackedStringArray([UUID_A])}}}
    preserve.load_file(fresh)
    check(preserve.chunk_to_uuid_map[Vector3i.ZERO] == PackedStringArray([UUID_A]) and preserve.chunk_to_uuid_map.is_typed(), "generic saved UUID map restores typed preservation index")
    preserve.free()
    var manager := Manager.new()
    manager.fixture_root = "user://instance_nodes_" + Crypto.new().generate_random_bytes(8).hex_encode()
    add_child(manager)
    var store = manager.personal_store
    var path: String = manager._profile_path("alice")
    var host_path: String = manager._profile_path("host")
    var guest_path: String = manager._profile_path("guest")
    var state: Dictionary = {"node": {"player": {"Inventory": {"capacity": 1, "items": [PackedInt32Array([7, 10, 0]), Vector3i.ZERO]}}}}
    var empty: Dictionary = {"node": {"player": {"Inventory": {"capacity": 1, "items": [PackedInt32Array(), Vector3i.ZERO]}}}}
    var alice: Dictionary = bundle(UUID_A, "pocket")
    check(store.save_checkpoint(path, empty, 0, "pocket__alice", "pocket", [alice], {SCENE: true}).get("revision") == 1, "profile and object one durable generation")
    var original: PackedByteArray = store.files._read_bytes(Store.storage_path(path))
    var failed = Store.new()
    failed.files = FailedFiles.new()
    check(failed.save_checkpoint(path, state, 1, "pocket__alice", "pocket", [], {SCENE: true}).is_empty(), "failed pickup not acknowledged")
    check(store.files._read_bytes(Store.storage_path(path)) == original and store.read_profile(path)["state"] == empty and store.instance_bundles(path, "pocket__alice")["bundles"].size() == 1, "failed pickup keeps inventory and object after restart")
    check(store.commit_lease(path, 1, {}, {}, [{"instance": "pocket__alice", "uuid": UUID_A, "old": "alice", "new": "guest"}]), "host-authorized transfer to guest")
    check(store.save_checkpoint(path, empty, 1, "pocket__alice", "pocket", [], {SCENE: true}).get("revision") == 2 and store.instance_bundles(path, "pocket__alice")["bundles"].size() == 1, "former owner missing snapshot cannot delete transferred UUID")
    check(store.commit_lease(path, 2, {}, {}, [{"instance": "pocket__alice", "uuid": UUID_A, "old": "guest", "new": "alice"}]) and store.commit_lease(path, 3, {}, {}, [{"instance": "pocket__alice", "uuid": UUID_A, "old": "alice", "new": "guest"}]), "legitimate return handoff")
    check(store.save_checkpoint(guest_path, state, 0, "pocket__alice", "pocket", [], {SCENE: true}).get("revision") == 1, "guest pickup commits inventory and deletion")
    check(store.read_profile(guest_path)["state"] == state and store.instance_bundles(path, "pocket__alice")["bundles"].is_empty(), "successful pickup survives fresh read")
    check(store.save_checkpoint(path, empty, 2, "pocket__alice", "pocket", [alice], {SCENE: true}).get("revision") == 3 and store.instance_bundles(path, "pocket__alice")["bundles"].is_empty(), "permanent tombstone blocks stale former owner resurrection")
    check(store.commit_lease(path, 4, {}, {}, [{"instance": "pocket__alice", "uuid": UUID_A, "old": "alice", "new": "guest"}]) and store.instance_bundles(path, "pocket__alice")["bundles"].is_empty() and not store.read_ledger(path)["instances"]["pocket__alice"]["owners"].has(UUID_A), "tombstone cannot transfer: the transfer is skipped and the object stays deleted")
    var bob: Dictionary = bundle(UUID_B, "pocket")
    var bob_path: String = manager._profile_path("bob")
    check(store.save_checkpoint(bob_path, empty, 0, "pocket__bob", "pocket", [bob], {SCENE: true}).get("revision") == 1, "second private instance checkpoint")
    var snapshot: Dictionary = {"pocket": {"node": {"player": {"health": 1}, UUID_A: {"nickname": "other owner"}}}}
    check(manager._merge_instance_nodes_into_snapshot(snapshot, "pocket:bob", 3, "bob"), "private snapshot reads shared ledger")
    check(snapshot["pocket"]["node"].has(UUID_B) and not snapshot["pocket"]["node"].has(UUID_A) and snapshot["pocket"]["node"]["player"]["health"] == 1, "private snapshot isolates owner and preserves visiting player")
    check(snapshot["pocket"]["world"]["chunk_to_uuid_map"][Vector3i.ZERO].has(UUID_B), "restored node attached to correct chunk")
    var forged: Dictionary = bob.duplicate(true)
    forged["scene_path"] = "res://mods/arbitrary.tscn"
    check(store.save_checkpoint(bob_path, empty, 1, "pocket__bob", "pocket", [forged], {SCENE: true}).is_empty(), "unknown preserved scene rejected")
    forged = bob.duplicate(true)
    forged["save_data"]["pocket"]["node"]["player"] = {}
    check(store.save_checkpoint(bob_path, empty, 1, "pocket__bob", "pocket", [forged], {SCENE: true}).is_empty(), "player node overwrite rejected")
    var legacy: Dictionary = {"pocket": {"node": {"player": {"health": 1}, UUID_A: {"global_position": Vector3.ZERO, "file_path": SCENE}}}}
    var legacy_before: Dictionary = legacy.duplicate(true)
    check(not manager._merge_instance_nodes_into_snapshot(legacy, "pocket:host", 3, "host", "other_owner") and legacy == legacy_before, "ambiguous legacy owner refused without clearing preserved objects")
    check(manager._merge_instance_nodes_into_snapshot(legacy, "pocket:host", 3, "host", "host") and legacy["pocket"]["node"] == legacy_before["pocket"]["node"], "proven local source owner retains legacy objects for first atomic checkpoint")
    var qualified: Dictionary = {"pocket": {"node": {"player": {}}}, "pocket__host": {"node": {UUID_A: {"global_position": Vector3.ZERO, "file_path": SCENE}}}}
    check(manager._merge_instance_nodes_into_snapshot(qualified, "pocket:host", 3, "host", "") and qualified["pocket"]["node"].has(UUID_A) and qualified["pocket__host"]["node"].has(UUID_A), "explicit owner namespace retained and adopted without deleting source")
    var solo := Manager.new()
    solo.fixture_root = "user://solo_adoption_" + Crypto.new().generate_random_bytes(8).hex_encode()
    add_child(solo)
    var original_solo: Dictionary = legacy_before.duplicate(true)
    check(solo._merge_instance_nodes_into_snapshot(original_solo, "pocket:host", 3, "host", "") and original_solo["pocket"]["node"] == legacy_before["pocket"]["node"], "original solo empty owner adopts local host without losing nodes")
    var foreign_solo: Dictionary = legacy_before.duplicate(true)
    foreign_solo["coop"] = {"private_node_owners": {"pocket": "foreign"}}
    var foreign_before: Dictionary = foreign_solo.duplicate(true)
    check(not solo._merge_instance_nodes_into_snapshot(foreign_solo, "pocket:host", 3, "host", "") and foreign_solo == foreign_before, "foreign legacy ownership marker prevents solo adoption")
    solo.free()
    var prior_file = Ref.save_file_manager.loaded_file
    Ref.save_file_manager.loaded_file = SaveFile.new()
    var plain: String = SaveFile.DIMENSION_MAP[int(Ref.world.current_dimension)]
    SaveFile._set_data(Ref.save_file_manager.loaded_file.data, plain + "/node/" + UUID_B, bob["save_data"]["pocket"]["node"][UUID_B])
    var prior_nodes = Ref.preserve_node_manager.node_to_uuid_map.duplicate()
    var prior_chunks = Ref.preserve_node_manager.chunk_to_uuid_map.duplicate(true)
    Ref.preserve_node_manager.node_to_uuid_map.clear()
    Ref.preserve_node_manager.chunk_to_uuid_map.clear()
    Ref.preserve_node_manager.chunk_to_uuid_map[Vector3i.ZERO] = PackedStringArray([UUID_B])
    var captured: Array = manager._capture_local_instance_nodes()
    check(captured.size() == 1 and captured[0]["uuid"] == UUID_B and captured[0]["save_data"].has(plain), "unloaded saved UUID included in full checkpoint")
    Ref.preserve_node_manager.node_to_uuid_map.assign(prior_nodes)
    Ref.preserve_node_manager.chunk_to_uuid_map.assign(prior_chunks)
    Ref.save_file_manager.loaded_file = prior_file
    var handle = FileAccess.open(Store.storage_path(path), FileAccess.WRITE)
    handle.store_buffer(PackedByteArray([1, 2, 3]))
    handle.close()
    var untouched: Dictionary = snapshot.duplicate(true)
    check(store.read_ledger(path).is_empty() and not store.instance_bundles(path, "pocket__bob")["ok"], "corrupt ledger explicit failure")
    check(not manager._merge_instance_nodes_into_snapshot(snapshot, "pocket:bob", 3, "bob") and snapshot == untouched, "corrupt private snapshot refused without mutation")
    check(not manager.prepare_instance_preserved_state(SaveFile.new(), 3, "bob"), "corrupt host private load refused")
    manager.free()
    print("INSTANCE_NODES_RESULT ", checks, " checks ", failures, " failures")
    return failures
