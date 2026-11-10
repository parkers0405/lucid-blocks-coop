extends Node
var checks: int = 0
var failures: int = 0
func check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("PERSONAL_STORE_FAIL ", label)

class FailedStore extends "res://coop_mod/personal_store.gd":
    func commit(_path: String, _record: Dictionary) -> bool:
        return false

func run() -> int:
    var store = preload("res://coop_mod/personal_store.gd").new()
    var path: String = "user://personal_" + Crypto.new().generate_random_bytes(8).hex_encode() + "/alice.bin"
    var items: Array = [PackedInt32Array([7, 10, 0]), Vector3i(1, 2, 3), PackedInt32Array(), Vector3i.ZERO]
    var state: Dictionary = {"node": {"player": {"Inventory": {"items": items, "capacity": 2}}}}
    var record: Dictionary = store.save_checkpoint(path, state, 0, "fixture", "naraka", [], {})
    check(record.get("revision") == 1, "profile committed before acknowledgement")
    check(store.read_profile(path)["chest"].size() == 21, "bounded21 slots")
    var request: String = "a".repeat(64)
    var limit: Callable = func(_id): return 64
    record = store.transfer(path, 1, request, "Inventory", 0, 0, 4, true, limit)
    check(record.get("revision") == 2, "deposit committed")
    check(record["state"]["node"]["player"]["Inventory"]["items"][0][1] == 6 and record["chest"][0]["item"][1] == 4, "both sides conserve items")
    check(record["chest"][0]["position"] == Vector3i(1, 2, 3), "item position retained")
    check(store.transfer(path, 1, request, "Inventory", 0, 0, 4, true, limit)["revision"] == 2, "request replay idempotent")
    check(store.save_checkpoint(path, state, 1, "fixture", "naraka", [], {}).is_empty(), "stale profile cannot roll back chest inventory")
    check(store.transfer(path, 1, "b".repeat(64), "Inventory", 0, 0, 4, true, limit).is_empty(), "stale transfer rejected")
    check(store.transfer(path, 2, "b".repeat(64), "Inventory", 0, 21, 1, true, limit).is_empty(), "slot22 rejected")
    check(store.transfer(path, 2, "b".repeat(64), "Inventory", 0, 0, 7, true, limit).is_empty(), "overdraw rejected")
    check(store.transfer(path, 2, "b".repeat(64), "Inventory", 0, 0, 1, true, func(_id): return 4).is_empty(), "stack overflow rejected")
    var failing := FailedStore.new()
    check(failing.transfer(path, 2, "c".repeat(64), "Inventory", 0, 0, 1, true, limit).is_empty(), "write failure not acknowledged")
    check(store.read_profile(path)["revision"] == 2, "failed write preserves both original sides")
    record = store.transfer(path, 2, "d".repeat(64), "Inventory", 1, 0, 4, false, limit)
    check(record["chest"][0] == null and record["state"]["node"]["player"]["Inventory"]["items"][2][1] == 4, "withdrawal clears chest and fills destination")
    check(store.read_profile(path)["revision"] == 3, "restart reloads completed transaction")
    check(store.read_profile(path.get_base_dir().path_join("bob.bin"))["revision"] == 0, "another player/save isolated")
    var actual := ItemState.new()
    actual.id = 7
    actual.count = 10
    actual.durability = 0
    check(actual.get_save_data() == PackedInt32Array([7, 10, 0]), "actual native item serialization contract")
    # The simpler Store/Take branches must still compare item positions.
    var merge_path: String = path.get_base_dir().path_join("merge.bin")
    var merge_items: Array = [PackedInt32Array([7, 10, 0]), Vector3i(1, 2, 3), PackedInt32Array([7, 2, 0]), Vector3i(1, 2, 3)]
    var merge_state: Dictionary = {"node": {"player": {"Inventory": {"items": merge_items, "capacity": 2}}}}
    store.save_checkpoint(merge_path, merge_state, 0, "merge", "naraka", [], {})
    record = store.transfer(merge_path, 1, "e".repeat(64), "Inventory", 0, 0, 4, true, limit)
    record = store.transfer(merge_path, 2, "f".repeat(64), "Inventory", 0, 0, 2, true, limit)
    check(record.get("revision") == 3 and record["chest"][0]["item"][1] == 6, "deposit merges matching stacks")
    record = store.transfer(merge_path, 3, "1".repeat(64), "Inventory", 1, 0, 2, false, limit)
    check(record.get("revision") == 4 and record["state"]["node"]["player"]["Inventory"]["items"][2][1] == 4, "withdrawal merges matching stacks")
    merge_state = record["state"].duplicate(true)
    merge_state["node"]["player"]["Inventory"]["items"][1] = Vector3i(9, 9, 9)
    store.save_checkpoint(merge_path, merge_state, 4, "merge", "naraka", [], {})
    check(store.transfer(merge_path, 5, "2".repeat(64), "Inventory", 0, 0, 1, true, limit).is_empty(), "deposit refuses different item positions")
    check(store.transfer(merge_path, 5, "3".repeat(64), "Inventory", 0, 0, 1, false, limit).is_empty(), "withdrawal refuses different item positions")
    check(store.transfer(merge_path, 5, "4".repeat(64), "Inventory", 0, 1, 1, false, limit).is_empty(), "withdrawal from empty chest slot refused")
    check(store.read_profile(merge_path)["revision"] == 5, "refused transfers leave saved revision alone")
    print("PERSONAL_STORE_RESULT ", checks, " checks ", failures, " failures")
    return failures
