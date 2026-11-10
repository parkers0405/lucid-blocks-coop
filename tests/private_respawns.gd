extends Node
const Store = preload("res://coop_mod/personal_store.gd")
const UUID: String = "55555555-5555-4555-8555-555555555555"
const SCENE: String = "res://fixture_respawn.tscn"
class FailedFiles extends "res://coop_mod/region_checkpoint.gd":
    func _replace_file(_path: String, _bytes: PackedByteArray) -> bool:
        return false
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("PRIVATE_RESPAWNS_FAIL ", label)
func run() -> int:
    var store = Store.new()
    var path: String = "user://private_respawns_" + Crypto.new().generate_random_bytes(8).hex_encode() + "/host.bin"
    var guest: String = path.get_base_dir().path_join("guest.bin")
    var state: Dictionary = {"node": {"player": {"marker": "before"}}}
    var a := Vector3i(1, 2, 3)
    var b := Vector3i(33, 2, 3)
    var legacy := Vector3i(-33, 4, 5)
    var ca: Vector3i = Store.respawn_chunk(a)
    var cb: Vector3i = Store.respawn_chunk(b)
    var cl: Vector3i = Store.respawn_chunk(legacy)
    check(Store.valid_respawns({a: true}) and Store.respawn_chunk(Vector3i(-1, 0, 0)) == Vector3i(-16, 0, 0), "true integer coordinates and negative chunk snapping")
    check(not Store.valid_respawns({a: false}) and not Store.valid_respawns({a: 1}) and not Store.valid_respawns({Vector3.ZERO: true}), "false nonboolean and floating keys rejected")
    var excessive: Dictionary = {}
    for index in range(Store.MAX_RESPAWNS + 1):
        excessive[Vector3i(index, 0, 0)] = true
    check(not Store.valid_respawns(excessive), "map entry bound")
    check(not store.instance_respawns(path, "pocket__alice")["present"], "missing instance metadata is absent")
    var bundle: Dictionary = {"uuid": UUID, "scene_path": SCENE, "position": Vector3.ZERO, "save_data": {"pocket": {"node": {UUID: {}}}}}
    var record: Dictionary = store.save_checkpoint(path, state, 0, "pocket__alice", "pocket", [bundle], {SCENE: true})
    check(record.get("revision") == 1 and not store.instance_respawns(path, "pocket__alice")["present"], "old node-only record remains metadata-absent")
    record = store.save_checkpoint(path, state, 1, "pocket__alice", "pocket", [bundle], {SCENE: true}, {"positions": {a: true}, "chunks": [ca], "initial": {legacy: true}})
    check(record.get("revision") == 2 and store.instance_respawns(path, "pocket__alice")["positions"] == {a: true, legacy: true}, "explicit legacy seed preserves unloaded source points")
    var before: PackedByteArray = store.files._read_bytes(Store.storage_path(path))
    check(store.save_checkpoint(path, state, 2, "pocket__alice", "pocket", [bundle], {SCENE: true}, {"positions": {b: true}, "chunks": [ca]}).is_empty() and store.files._read_bytes(Store.storage_path(path)) == before, "point outside declared coverage cannot write")
    record = store.save_checkpoint(guest, state, 0, "pocket__alice", "pocket", [], {SCENE: true}, {"positions": {b: true}, "chunks": [cb]})
    check(record.get("revision") == 1 and store.instance_respawns(path, "pocket__alice")["positions"] == {a: true, b: true, legacy: true}, "visitor adds disjoint coverage without replacing owner map")
    record = store.save_checkpoint(path, state, 2, "pocket__alice", "pocket", [bundle], {SCENE: true}, {"positions": {}, "chunks": [ca]})
    check(record.get("revision") == 3 and store.instance_respawns(path, "pocket__alice")["positions"] == {b: true, legacy: true}, "stale owner deletion touches only explicit covered chunk")
    var failed = Store.new()
    failed.files = FailedFiles.new()
    before = store.files._read_bytes(Store.storage_path(path))
    check(failed.save_checkpoint(path, {"node": {"player": {"marker": "failed"}}}, 3, "pocket__alice", "pocket", [], {SCENE: true}, {"positions": {a: true}, "chunks": [ca]}).is_empty(), "failed atomic metadata checkpoint not acknowledged")
    check(store.files._read_bytes(Store.storage_path(path)) == before and store.read_profile(path)["state"] == state and store.instance_bundles(path, "pocket__alice")["bundles"].size() == 1 and store.instance_respawns(path, "pocket__alice")["positions"] == {b: true, legacy: true}, "failed write preserves profile nodes and metadata together")
    record = store.save_checkpoint(guest, state, 1, "pocket__alice", "pocket", [], {SCENE: true}, {"positions": {}, "chunks": [cb]})
    check(record.get("revision") == 2 and store.instance_respawns(path, "pocket__alice")["positions"] == {legacy: true}, "visitor deletion retains unloaded owner point")
    record = store.save_checkpoint(path, state, 3, "pocket__alice", "pocket", [bundle], {SCENE: true}, {"positions": {}, "chunks": [cl]})
    var empty: Dictionary = store.instance_respawns(path, "pocket__alice")
    check(record.get("revision") == 4 and empty["present"] and empty["positions"].is_empty(), "intentional empty map is durable and distinct from absence")
    check(store.save_checkpoint(path, state, 4, "pocket__alice", "pocket", [bundle], {SCENE: true}, {"positions": {}, "chunks": [], "initial": {legacy: true}}).is_empty() and store.instance_respawns(path, "pocket__alice")["positions"].is_empty(), "legacy seed cannot resurrect deliberately empty canonical map")
    check(store.save_state(path, state, 4).get("revision") == 5 and store.instance_respawns(path, "pocket__alice")["present"], "ordinary profile save preserves metadata presence")
    record = store.save_checkpoint(path, state, 5, "pocket__bob", "pocket", [], {SCENE: true}, {"positions": {b: true}, "chunks": [cb]})
    check(record.get("revision") == 6 and store.instance_respawns(path, "pocket__alice")["positions"].is_empty() and store.instance_respawns(path, "pocket__bob")["positions"] == {b: true}, "same coordinates in separate owner instances stay isolated")
    check(not Store.valid_respawn_update({"positions": {}, "chunks": [ca, ca]}) and not Store.valid_respawn_update({"positions": {}, "chunks": [Vector3i.ONE]}), "duplicate and unsnapped coverage rejected")
    var oversized: Array = []
    for index in range(8193):
        oversized.append(Vector3i(index * 16, 0, 0))
    check(not Store.valid_respawn_update({"positions": {}, "chunks": oversized}), "coverage entry bound")
    var restarted = Store.new()
    check(restarted.instance_respawns(path, "pocket__alice")["present"] and restarted.instance_respawns(path, "pocket__bob")["positions"] == {b: true}, "restart restores empty and nonempty maps independently")
    var corrupt: Dictionary = store.read_ledger(path)
    corrupt["instances"]["pocket__bob"]["respawn_positions"][b] = false
    store.files._replace_file(Store.storage_path(path), var_to_bytes(corrupt))
    check(not store.instance_respawns(path, "pocket__bob")["ok"] and store.read_profile(path).is_empty(), "invalid persisted respawn map fails entire ledger closed")
    print("PRIVATE_RESPAWNS_RESULT ", checks, " checks ", failures, " failures")
    return failures