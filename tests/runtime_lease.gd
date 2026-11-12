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
    # H4: ownership diff, order-independent hash, versions seeded without fingerprints.
    var prev_map: Dictionary = {"i:0,0,0": 1, "i:16,0,0": 2, "i:32,0,0": 2}
    var next_map: Dictionary = {"i:16,0,0": 1, "i:32,0,0": 2, "i:48,0,0": 2}
    var diff: Dictionary = Authority.owner_diff(prev_map, next_map)
    check(diff == {"i:0,0,0": 0, "i:16,0,0": 1, "i:48,0,0": 2}, "owner diff lists changed and removed keys only")
    check(Authority.apply_diff(prev_map, diff) == next_map, "apply_diff(prev, diff(prev, next)) == next")
    check(Authority.map_hash(Authority.apply_diff(prev_map, diff)) == Authority.map_hash({"i:48,0,0": 2, "i:32,0,0": 2, "i:16,0,0": 1}) and Authority.map_hash(prev_map) != Authority.map_hash(next_map), "map hash ignores insertion order and tells maps apart")
    var seeded = Authority.new()
    seeded.seed_versions("i", {"chunk_block": {Vector3i.ZERO: PackedByteArray([1])}}, "", {"i:0,0,0": 7})
    check(seeded.revisions.get("i:0,0,0") == 7 and seeded.fingerprints.is_empty(), "seed_versions sets revisions and leaves the fingerprint unset")
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
    check(store.save_checkpoint(guest_path, inventory, 0, "dimension__2", "naraka", [bundle], {DROP: true}).get("revision") == 1, "guest pre-pickup inventory ready")
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
    check(store.save_checkpoint(spill_path, full, 1, "spill", "naraka", [bundle], {DROP: true}).get("revision") == 2, "partially fitting inventory fixture committed")
    var partial: Dictionary = store.collect_drop(spill_path, 2, "c".repeat(64), "spill", UUID, func(_id): return 64)
    var remainder: Dictionary = partial.get("_coop_pickup_bundle", {})
    var remainder_count: int = remainder["save_data"]["naraka"]["node"][UUID][""]["items"][0][1]
    check(partial.get("revision") == 3 and partial["state"]["node"]["player"]["Inventory"]["items"][0][1] == 64 and remainder_count == 3, "partial pickup fills one slot and durably retains three items")
    check(store.collect_drop(spill_path, 2, "c".repeat(64), "spill", UUID, func(_id): return 64).get("revision") == 3, "partial pickup retry returns existing result")
    full = partial["state"].duplicate(true)
    full["node"]["player"]["Inventory"]["items"][2] = PackedInt32Array()
    check(store.save_checkpoint(spill_path, full, 3, "spill", "naraka", [remainder], {DROP: true}).get("revision") == 4, "remainder and freed slot committed")
    var split: Dictionary = store.collect_drop(spill_path, 4, "d".repeat(64), "spill", UUID, func(_id): return 64)
    var split_items: Array = split["state"]["node"]["player"]["Inventory"]["items"]
    check(split_items[0][1] == 64 and split_items[2][1] == 3 and store.instance_bundles(path, "spill")["bundles"].is_empty(), "second pickup conserves all four items and removes exact UUID")
    # H3: transfers racing with pickups and spawns while play continues.
    var late: String = "33333333-3333-4333-8333-333333333333"
    var late_bundle: Dictionary = {"uuid": late, "position": Vector3.ZERO, "scene_path": DROP, "save_data": {"naraka": {"node": {late: {"global_position": Vector3.ZERO}}}}}
    var base_epoch: int = 10
    var tomb: Array = [{"instance": "spill", "uuid": UUID, "old": "host", "new": "guest"}]
    check(store.commit_lease(path, base_epoch, {}, {}, tomb) and store.read_ledger(path)["lease"]["epoch"] == base_epoch and store.read_ledger(path)["instances"]["spill"]["tombstones"].has(UUID) and not store.read_ledger(path)["instances"]["spill"]["owners"].has(UUID), "tombstoned transfer skipped, commit succeeds")
    var insert: Array = [{"instance": "spill", "uuid": late, "old": "host", "new": "guest", "bundle": late_bundle}]
    check(not store.commit_lease(path, base_epoch + 1, {}, {}, insert) and store.read_ledger(path)["lease"]["epoch"] == base_epoch, "bundle with a scene outside the allowed set rejected, epoch unchanged")
    check(store.commit_lease(path, base_epoch + 1, {}, {}, insert, {DROP: true}) and store.read_ledger(path)["instances"]["spill"]["owners"][late] == "guest" and store.instance_bundles(path, "spill")["bundles"].size() == 1, "absent uuid with a bundle inserted under the new owner")
    var update: Array = [{"instance": "spill", "uuid": late, "old": "guest", "new": "host", "bundle": late_bundle.duplicate(true)}]
    update[0]["bundle"]["position"] = Vector3(7, 0, 0)
    check(store.commit_lease(path, base_epoch + 2, {}, {}, update, {DROP: true}) and store.read_ledger(path)["instances"]["spill"]["owners"][late] == "host" and store.read_ledger(path)["instances"]["spill"]["nodes"][late]["position"] == Vector3(7, 0, 0), "present uuid takes the new owner and the captured bundle")
    var wrong_owner: Array = [{"instance": "spill", "uuid": late, "old": "guest", "new": "guest"}]
    check(not store.commit_lease(path, base_epoch + 3, {}, {}, wrong_owner) and store.read_ledger(path)["lease"]["epoch"] == base_epoch + 2, "owner mismatch still fails and leaves the epoch unchanged")
    check(not store.commit_lease(path, base_epoch + 3, {}, {}, [{"instance": "spill", "uuid": "44444444-4444-4444-8444-444444444444", "old": "host", "new": "guest"}]), "absent uuid without a bundle still fails")
    var corrupt: Dictionary = store.read_ledger(path)
    corrupt["lease"]["objects"]["broken"] = 8
    check(store.files._replace_file(Store.storage_path(path), var_to_bytes(corrupt)) and store.read_ledger(path).is_empty(), "corrupt durable lease fails closed")
    print("RUNTIME_LEASE_RESULT ", checks, " checks ", failures, " failures")
    return failures
