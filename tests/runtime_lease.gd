extends Node
const Authority = preload("res://coop_mod/chunk_authority.gd")
const Store = preload("res://coop_mod/personal_store.gd")
const DROP: String = "res://main/items/dropped_item/dropped_item.tscn"
const UUID: String = "11111111-1111-4111-8111-111111111111"
class FailedFiles extends "res://coop_mod/region_checkpoint.gd":
    func _replace_file(_path: String, _bytes: PackedByteArray) -> bool:
        return false
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("RUNTIME_LEASE_FAIL ", label)
func run() -> int:
    var authority = Authority.new()
    var chunk := Vector3i(192, 0, 0)
    var instance: String = "dimension:2"
    var key: String = Authority.chunk_key(instance, chunk)
    var host: Dictionary = {"dimension_instance_key": instance, "position": Vector3.ZERO, "active": true}
    var guest: Dictionary = {"dimension_instance_key": instance, "position": Vector3(200, 0, 0), "active": true}
    check(Authority.owner(chunk, instance, host, guest) == 2 and authority.leased_owner(chunk, instance) == 1, "positions propose without granting")
    check(authority.install_lease(1, {key: 2}, {instance + "|" + UUID: 1}), "committed lease installed")
    check(authority.leased_owner(chunk, instance) == 2 and authority.object_owner(UUID, instance, chunk) == 1, "UUID owner remains latched while crossing chunk boundary")
    host["position"] = Vector3(200, 0, 0)
    check(Authority.owner(chunk, instance, host, guest) == 1 and authority.leased_owner(chunk, instance) == 2, "approach cannot change committed owner")
    check(not authority.install_lease(1, {key: 1}, {}) and authority.leased_owner(chunk, instance) == 2, "old install epoch rejected")
    check(not authority.install_lease(2, {key: 3}, {}), "invalid rank rejected")
    check(not authority.install_lease(2, {key: 2.0}, {}), "non-integer rank rejected")
    var store = Store.new()
    var path: String = "user://runtime_lease_" + Crypto.new().generate_random_bytes(8).hex_encode() + "/host.bin"
    var guest_path: String = path.get_base_dir().path_join("guest.bin")
    var inventory: Dictionary = {"node": {"player": {"Inventory": {"capacity": 2, "items": [PackedInt32Array([7, 6, 0]), Vector3i.ZERO, PackedInt32Array(), Vector3i.ZERO]}}}}
    var bundle: Dictionary = {"uuid": UUID, "position": Vector3.ZERO, "scene_path": DROP, "save_data": {"naraka": {"node": {UUID: {"global_position": Vector3.ZERO, "": {"capacity": 1, "items": [PackedInt32Array([7, 4, 0]), Vector3i.ZERO]}}}}}}
    var first: Dictionary = store.save_checkpoint(path, inventory, 0, "dimension__2", "naraka", [bundle], {DROP: true})
    check(first.get("revision") == 1, "drop and pre-pickup inventory checkpoint")
    var original: PackedByteArray = store.files._read_bytes(Store.storage_path(path))
    check(not store.commit_lease(path, 1, {key: "guest"}, {}, []) and store.files._read_bytes(Store.storage_path(path)) == original, "malformed durable lease rejected without writes")
    var transfers: Array = [{"instance": "dimension__2", "uuid": UUID, "old": "host", "new": "guest"}]
    var failing = Store.new()
    failing.files = FailedFiles.new()
    check(not failing.commit_lease(path, 1, {key: 2}, {instance + "|" + UUID: 2}, transfers) and store.read_ledger(path)["instances"]["dimension__2"]["owners"][UUID] == "host", "failed lease commit preserves old UUID owner")
    check(store.commit_lease(path, 1, {key: 2}, {instance + "|" + UUID: 2}, transfers), "owner CAS and epoch commit together")
    check(store.read_ledger(path)["lease"]["epoch"] == 1 and store.read_ledger(path)["instances"]["dimension__2"]["owners"][UUID] == "guest", "restart sees matching owner and epoch")
    check(not store.commit_lease(path, 1, {key: 1}, {}, []) and not store.commit_lease(path, 2, {key: 1}, {}, transfers), "stale epoch or stale expected owner cannot commit")
    check(store.save_state(guest_path, inventory, 0).get("revision") == 1, "guest pre-pickup inventory ready")
    var request: String = "a".repeat(64)
    original = store.files._read_bytes(Store.storage_path(path))
    check(failing.collect_drop(guest_path, 1, request, "dimension__2", UUID, func(_id): return 64).is_empty() and store.files._read_bytes(Store.storage_path(path)) == original, "failed pickup preserves drop and inventory together")
    var picked: Dictionary = store.collect_drop(guest_path, 1, request, "dimension__2", UUID, func(_id): return 64)
    check(picked.get("revision") == 2 and picked["state"]["node"]["player"]["Inventory"]["items"][0][1] == 10, "pickup commits actual item count into inventory")
    check(store.instance_bundles(path, "dimension__2")["bundles"].is_empty() and store.read_ledger(path)["instances"]["dimension__2"]["tombstones"].has(UUID), "pickup commits exact UUID deletion")
    check(store.collect_drop(guest_path, 1, request, "dimension__2", UUID, func(_id): return 64)["revision"] == 2, "duplicate receipt returns committed profile without replay")
    check(store.collect_drop(guest_path, 2, "b".repeat(64), "dimension__2", UUID, func(_id): return 64).is_empty(), "new receipt cannot collect deleted UUID")
    var spill_path: String = path.get_base_dir().path_join("spill.bin")
    var full: Dictionary = {"node": {"player": {"Inventory": {"capacity": 2, "items": [PackedInt32Array([7, 64, 0]), Vector3i.ZERO, PackedInt32Array([7, 64, 0]), Vector3i.ZERO]}}}}
    check(store.save_checkpoint(spill_path, full, 0, "spill", "naraka", [bundle], {DROP: true}).get("revision") == 1, "capacity fixture starts with exact UUID")
    original = store.files._read_bytes(Store.storage_path(path))
    check(store.collect_drop(spill_path, 1, "c".repeat(64), "spill", UUID, func(_id): return 64).is_empty() and store.files._read_bytes(Store.storage_path(path)) == original, "full inventory retains drop and bytes")
    full["node"]["player"]["Inventory"]["items"][0][1] = 63
    check(store.save_state(spill_path, full, 1).get("revision") == 2, "partially fitting inventory fixture committed")
    original = store.files._read_bytes(Store.storage_path(path))
    check(store.collect_drop(spill_path, 2, "c".repeat(64), "spill", UUID, func(_id): return 64).is_empty() and store.files._read_bytes(Store.storage_path(path)) == original, "partial fit cannot remove or partially credit drop")
    full["node"]["player"]["Inventory"]["items"][2] = PackedInt32Array()
    check(store.save_state(spill_path, full, 2).get("revision") == 3, "spill inventory fixture committed")
    var split: Dictionary = store.collect_drop(spill_path, 3, "c".repeat(64), "spill", UUID, func(_id): return 64)
    var split_items: Array = split["state"]["node"]["player"]["Inventory"]["items"]
    check(split_items[0][1] == 64 and split_items[2][1] == 3 and store.instance_bundles(path, "spill")["bundles"].is_empty(), "cross-slot spill conserves all four items and removes exact UUID")
    var corrupt: Dictionary = store.read_ledger(path)
    corrupt["lease"]["objects"]["broken"] = 8
    check(store.files._replace_file(Store.storage_path(path), var_to_bytes(corrupt)) and store.read_ledger(path).is_empty(), "corrupt durable lease fails closed")
    print("RUNTIME_LEASE_RESULT ", checks, " checks ", failures, " failures")
    return failures
