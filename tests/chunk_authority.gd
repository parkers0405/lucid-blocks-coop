extends Node
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("CHUNK_AUTHORITY_FAIL ", label)

func run() -> int:
    var authority = preload("res://coop_mod/chunk_authority.gd").new()
    var host: Dictionary = {"dimension_instance_key": "naraka", "position": Vector3.ZERO, "active": true}
    var guest: Dictionary = {"dimension_instance_key": "naraka", "position": Vector3(1000, 0, 0), "active": true}
    check(authority.owner(Vector3i.ZERO, "naraka", host, guest) == 1, "host owns overlap")
    check(authority.owner(Vector3i(992, 0, 0), "naraka", host, guest) == 2, "distant guest bubble independent")
    guest["dimension_instance_key"] = "pocket:alice"
    check(authority.owner(Vector3i(992, 0, 0), "naraka", host, guest) == 1, "dimensions isolated")
    check(authority.owner(Vector3i(992, 0, 0), "pocket:alice", host, guest) == 2, "private instance guest simulation")
    var root: Dictionary = {"test_chunk_block": {Vector3i.ZERO: PackedInt32Array([7])}}
    check(authority.current("naraka", root, "test_", {}), "initial generation")
    var versions: Dictionary = authority.accept("naraka", root, "test_")
    check(not authority.current("naraka", root, "test_", {}), "stale generation refused")
    check(authority.current("naraka", root, "test_", versions), "matching generation accepted")
    check(authority.changed("naraka", root, "test_").is_empty(), "unchanged chunks not retransmitted")
    root["test_chunk_block"][Vector3i.ZERO][0] = 8
    check(authority.changed("naraka", root, "test_").size() == 1, "changed cells detected")
    authority.accept("naraka", root, "test_")
    check(not authority.current("naraka", root, "test_", versions), "prior revision cannot overwrite later edit")
    authority.seed("naraka", root, "test_", {})
    check(authority.current("naraka", root, "test_", {}) and authority.changed("naraka", root, "test_").is_empty(), "canonical seed preserves zero revision without inventing commits")
    for channel in ["chunk_water", "chunk_water_awake", "chunk_fire"]:
        root["test_" + channel] = {Vector3i.ZERO: PackedByteArray([1])}
        check(authority.changed("naraka", root, "test_") == [Vector3i.ZERO], channel + " changes trigger a checkpoint")
        authority.accept("naraka", root, "test_")
    authority.seed("naraka", root, "test_", {})
    check(authority.changed("naraka", root, "test_").is_empty(), "canonical seed fingerprints block water awake and fire together")
    var chunks: Array = []
    for index in range(35):
        chunks.append(Vector3i(index * 16, 0, 0))
    var batches: Array = authority.batches(chunks)
    check(batches.size() == 3 and batches[0].size() == 16 and batches[1].size() == 16 and batches[2].size() == 3, "network checkpoint batches bounded to16 chunks")
    check(batches[0] + batches[1] + batches[2] == chunks, "batching retains every chunk exactly once in order")
    print("CHUNK_AUTHORITY_RESULT ", checks, " checks ", failures, " failures")
    return failures
