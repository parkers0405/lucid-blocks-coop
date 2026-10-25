extends Node

var failures: int = 0
var checks: int = 0
var checkpoint_script: GDScript

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("REGION_FAIL ", label)

func chunk(block_id: int = 1000) -> Dictionary:
    var blocks := PackedInt32Array()
    blocks.resize(4096)
    blocks.fill(block_id)
    var fluid := PackedByteArray()
    fluid.resize(4096)
    var awake := PackedByteArray()
    awake.resize(64)
    return {"chunk_block": {Vector3i(-16, 0, 0): blocks}, "chunk_water": {Vector3i(-16, 0, 0): fluid}, "chunk_water_awake": {Vector3i(-16, 0, 0): awake}, "chunk_fire": {Vector3i(-16, 0, 0): fluid}}

func legacy(region_namespace: String, block_id: int) -> Dictionary:
    var channels: Dictionary = {}
    for channel in chunk(block_id):
        channels[region_namespace + "_" + channel] = chunk(block_id)[channel]
    return {region_namespace + "_world": channels}

func run() -> int:
    checkpoint_script = load(get_script().resource_path.get_base_dir().path_join("../mod/overrides/coop_mod/region_checkpoint.gd"))
    var store = checkpoint_script.new()
    var root: String = OS.get_user_data_dir().path_join("region-fixture-" + Crypto.new().generate_random_bytes(8).hex_encode())
    var ids: Dictionary = {1000: true, 2000: true}
    var coordinate := Vector3i(-1, 0, 0)
    var data: Dictionary = chunk()
    for channel in checkpoint_script.CHANNELS:
        data[channel][Vector3i(-32, 0, 0)] = data[channel][Vector3i(-16, 0, 0)].duplicate()
    data["coordinate"] = coordinate
    data["save_version"] = "5.1.0"
    var canonical: String = root.path_join("pocket__alice/c-1.0.0.txt")
    DirAccess.make_dir_recursive_absolute(canonical.get_base_dir())
    var canonical_bytes: PackedByteArray = JSON.stringify(JSON.from_native(data)).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
    check(store._write_verified(canonical, canonical_bytes), "canonical fixture written")
    check(checkpoint_script.region_coordinate(Vector3i(-272, -1, 256)) == Vector3i(-2, -1, 1), "negative floor coordinates")
    check(not checkpoint_script.valid_component("../alice"), "namespace traversal rejected")
    var update: Dictionary = {coordinate: {"chunk_block": {Vector3i(-16, 0, 0): chunk(2000)["chunk_block"][Vector3i(-16, 0, 0)]}}}
    for iteration in range(3):
        check(store.commit_regions(root, "pocket__alice", update, ids)["ok"], "manifest replace " + str(iteration))
    var loaded: Dictionary = store.read_regions(root, "pocket__alice", ids)
    check(loaded["ok"], "checkpoint readable")
    if loaded["ok"]:
        var region: Dictionary = loaded["regions"][coordinate]
        check(region["chunk_block"][Vector3i(-16, 0, 0)][0] == 2000, "block IDs above255 roundtrip")
        check(region["chunk_water_awake"][Vector3i(-16, 0, 0)].size() == 64, "partial patch preserves awake")
        check(region["chunk_fire"].size() == 2, "partial patch preserves fire")
        check(region["chunk_block"][Vector3i(-32, 0, 0)][0] == 1000, "untouched existing chunk preserved")
    check(store._read_bytes(canonical) == canonical_bytes, "canonical region untouched")
    check(store.commit_regions(root, "pocket__bob", {coordinate: chunk()}, ids)["ok"], "second owner commit")
    check(store.read_regions(root, "pocket__bob", ids)["regions"][coordinate]["chunk_block"][Vector3i(-16, 0, 0)][0] == 1000, "owner isolation")
    var manifest: String = root.path_join("coop/pocket__alice/manifest.json")
    var before: PackedByteArray = store._read_bytes(manifest)
    var bad := PackedByteArray()
    bad.resize(4096)
    check(not store.commit_regions(root, "pocket__alice", {coordinate: {"chunk_water_awake": {Vector3i(-16, 0, 0): bad}}}, ids)["ok"], "invalid awake length rejected")
    check(not store.commit_regions(root, "../escape", update, ids)["ok"], "invalid namespace commit rejected")
    check(not store.commit_regions(root, "pocket__alice", {coordinate: chunk(3333)}, ids)["ok"], "unknown block ID rejected")
    check(store._read_bytes(manifest) == before, "invalid patches preserve manifest")
    check(store._write_verified(manifest, "broken".to_utf8_buffer()), "corruption fixture")
    check(not store.commit_regions(root, "pocket__alice", update, ids)["ok"], "corrupt manifest fails closed")
    check(store._read_bytes(manifest).get_string_from_utf8() == "broken", "corrupt manifest preserved")
    var old_data: Dictionary = legacy("pocket", 1000)
    old_data.merge(legacy("pocket__carol", 2000))
    var original: Dictionary = old_data.duplicate(true)
    check(store.migrate_legacy(root, "pocket__carol", "pocket", old_data, ids)["ok"], "owned legacy conversion")
    check(store.read_regions(root, "pocket__carol", ids)["regions"][coordinate]["chunk_block"][Vector3i(-16, 0, 0)][0] == 2000, "owned legacy beats plain conflict")
    check(old_data == original, "migration retains all original keys")
    check(store.migrate_legacy(root, "pocket__carol", "pocket", legacy("pocket__carol", 1000), ids)["ok"], "existing checkpoint reload")
    check(store.read_regions(root, "pocket__carol", ids)["regions"][coordinate]["chunk_block"][Vector3i(-16, 0, 0)][0] == 2000, "checkpoint beats stale legacy")
    check(store.migrate_legacy(root, "pocket__dave", "pocket", legacy("pocket", 1000), ids)["ok"] and not store.has_checkpoint(root, "pocket__dave"), "plain data never assigned to arbitrary visitor")
    check(store.migrate_legacy(root, "pocket__erin", "pocket", legacy("pocket", 1000), ids, true)["ok"], "explicit local adoption converts plain legacy")
    print("REGION_RESULT ", checks, " checks ", failures, " failures root=", root)
    return failures
