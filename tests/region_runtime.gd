extends Node

class FailStore extends "res://coop_mod/region_checkpoint.gd":
    func _replace_file(path: String, bytes: PackedByteArray) -> bool:
        if path.ends_with("manifest.json"):
            return false
        return super._replace_file(path, bytes)

class LegacyWorldFixture extends "res://main/world/world.gd":
    var fixture_root: String
    var ids: Dictionary
    func _checkpoint_chunks_directory() -> String:
        return fixture_root
    func get_checkpoint_block_ids() -> Dictionary:
        return ids
    func select_generator() -> void:
        pass

class ManagerFixture extends "res://coop_mod/coop_manager.gd":
    var fixture_root: String
    var ids: Dictionary
    var replies: Array = []
    var fixture_patch: Dictionary = {}
    func _can_sample_player() -> bool:
        return true
    func _capture_local_world_patch() -> Dictionary:
        return fixture_patch
    func _ready() -> void:
        pass
    func _physics_process(_delta: float) -> void:
        pass
    func _update_status_text() -> void:
        pass
    func _get_checkpoint_chunks_directory() -> String:
        return fixture_root
    func _checkpoint_block_ids() -> Dictionary:
        return ids
    func _merge_world_patch_into_cache(_patch: Dictionary) -> void:
        pass
    func _send_region_checkpoint_result(_peer_id: int, _request_id: int, committed: bool) -> void:
        replies.append(committed)

var failures: int = 0
var checks: int = 0
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("REGION_RUNTIME_FAIL ", label)

func run() -> int:
    var pure = load(get_script().resource_path.get_base_dir().path_join("region_checkpoint.gd")).new()
    add_child(pure)
    failures += pure.run()
    var manager := ManagerFixture.new()
    add_child(manager)
    manager.fixture_root = OS.get_user_data_dir().path_join("region-native-" + Crypto.new().generate_random_bytes(8).hex_encode())
    var blocks: Array = Ref.world.get_block_types()
    var selected_id: int = -1
    for block in blocks:
        manager.ids[block.id] = true
        if block.id > 255:
            selected_id = block.id
    check(selected_id > 255, "native test block ID above255 exists")
    if selected_id < 0:
        manager.free()
        pure.free()
        return failures
    var data: Dictionary = pure.chunk(selected_id)
    var patch: Dictionary = {"dimension": 3, "pocket_owner_key": "alice", "dimension_instance_key": "pocket:alice", "world_data": {"pocket__alice_world": {}}, "checkpoint_request_id": 1, "host_flush_request_id": 9}
    for channel in data:
        patch["world_data"]["pocket__alice_world"]["pocket__alice_" + channel] = data[channel]
    manager.peer_states[2] = {"dimension": 3, "pocket_owner_key": "alice", "player_key": "alice", "dimension_instance_key": "pocket:alice"}
    manager.pending_guest_world_patch_flush_acks[9] = {2: "pocket:alice"}
    check(manager._checkpoint_and_reply(2, patch), "host checkpoint commit")
    check(manager.replies == [true], "success ACK after commit")
    check(not manager.pending_guest_world_patch_flush_acks.has(9), "successful durable flush cleared")
    var manifest: String = manager.fixture_root.path_join("coop/pocket__alice/manifest.json")
    var before: PackedByteArray = manager.region_checkpoint._read_bytes(manifest)
    manager.region_checkpoint = FailStore.new()
    manager.pending_guest_world_patch_flush_acks[9] = {2: "pocket:alice"}
    check(not manager._checkpoint_and_reply(2, patch), "failed manifest publish")
    check(manager.replies == [true, false], "failed write never success ACK")
    check(manager.pending_guest_world_patch_flush_acks.has(9), "failed flush remains pending")
    check(manager.failed_guest_world_patch_flushes.has(9), "host observes failed flush")
    check(manager.region_checkpoint._read_bytes(manifest) == before, "failed publish preserves prior manifest")
    var committed: Dictionary = manager.region_checkpoint.read_regions(manager.fixture_root, "pocket__alice", manager.ids)
    check(committed["ok"], "prior generation remains usable")
    var forged: Dictionary = patch.duplicate(true)
    forged["dimension"] = 5
    check(not manager._validate_guest_world_patch(manager.peer_states[2], forged), "independent dimension validation")
    forged = patch.duplicate(true)
    forged["pocket_owner_key"] = "bob"
    check(not manager._validate_guest_world_patch(manager.peer_states[2], forged), "independent owner validation")
    var wrong_identity: Dictionary = manager.peer_states[2].duplicate(true)
    wrong_identity["player_key"] = "bob"
    check(not manager._validate_guest_world_patch(wrong_identity, patch), "owner must match recorded player")
    manager.fixture_patch = patch
    var pending_before: Dictionary = Ref.world.pending_dimension_instance.duplicate(true)
    await manager._open_dimension_instance_async(3, "bob")
    check(Ref.world.pending_dimension_instance == pending_before, "failed host commit cancels owner switch")
    check(not manager.group_dimension_transfer_in_progress, "failed host transition inactive")
    await manager._host_save_and_quit_to_main_menu()
    check(not manager.local_quit_in_progress, "failed host exit preserves session")
    check(not manager.clear_fake_death_override_after_shutdown, "failed host exit leaves shutdown flags untouched")
    await manager._travel_group_to_dimension_async(3, false, false, "bob")
    check(Ref.world.pending_dimension_instance == pending_before, "failed group travel retains source owner")
    var owner_world = Ref.world
    var prior_dimension: int = owner_world.current_dimension
    owner_world.current_dimension = 3
    var source_register := SaveFileRegister.new()
    source_register.is_dimensional = false
    source_register.set_data("pocket_owner_key", "alice", true)
    var prior_register = Ref.save_file_manager.loaded_file_register
    Ref.save_file_manager.loaded_file_register = source_register
    check(not owner_world.queue_dimension_instance(3, "../bob"), "destination traversal rejected before switching")
    check(owner_world.queue_dimension_instance(3, "bob"), "valid destination queued")
    check(owner_world._get_dimension_save_namespace() == "pocket__alice", "queued destination does not rename outgoing world")
    manager.region_checkpoint = load("res://coop_mod/region_checkpoint.gd").new()
    check(manager._checkpoint_local_host_world(), "source checkpoint succeeds before switch")
    check(not manager.region_checkpoint.has_checkpoint(manager.fixture_root, "pocket__bob"), "outgoing save never writes destination namespace")
    check(owner_world.apply_pending_dimension_instance(source_register), "incoming load consumes destination owner")
    check(owner_world._get_dimension_save_namespace() == "pocket__bob", "incoming namespace changes only after source save")
    check(manager.region_checkpoint.read_regions(manager.fixture_root, "pocket__alice", manager.ids)["ok"], "source checkpoint preserved after owner switch")
    Ref.save_file_manager.loaded_file_register = prior_register
    owner_world.current_dimension = prior_dimension
    owner_world.pending_dimension_instance = pending_before
    source_register = null
    prior_register = null
    var native_world = ClassDB.instantiate("World")
    native_world.set_block_types(blocks)
    native_world.start_up()
    native_world.load_region(committed["regions"][Vector3i(-1, 0, 0)])
    var roundtrip: Dictionary = {}
    native_world.save_data(roundtrip, "native_")
    check(roundtrip["native_world"]["native_chunk_block"][Vector3i(-16, 0, 0)][0] == selected_id, "actual native load_region preserves block IDs")
    check(roundtrip["native_world"]["native_chunk_water_awake"][Vector3i(-16, 0, 0)].size() == 64, "actual native awake format")
    var legacy_world := LegacyWorldFixture.new()
    legacy_world.fixture_root = manager.fixture_root.path_join("legacy")
    legacy_world.ids = manager.ids
    legacy_world.set_block_types(blocks)
    legacy_world.start_up()
    var legacy_file := SaveFile.new()
    legacy_file.is_dimensional = false
    var other_id: int = manager.ids.keys()[0]
    legacy_file.data = pure.legacy("pocket", other_id)
    legacy_file.data.merge(pure.legacy("pocket__bob", selected_id))
    var legacy_register := SaveFileRegister.new()
    legacy_register.is_dimensional = false
    legacy_register.data = {"uuid": "migration_fixture", "pocket_owner_key": "alice"}
    var old_register = Ref.save_file_manager.loaded_file_register
    var old_file = Ref.save_file_manager.loaded_file
    Ref.save_file_manager.loaded_file_register = legacy_register
    Ref.save_file_manager.loaded_file = legacy_file
    DirAccess.make_dir_recursive_absolute(Ref.save_file_manager.get_save_file_directory("migration_fixture", false))
    legacy_world.current_dimension = 3
    legacy_world.queue_dimension_instance(3, "bob")
    var originals: Dictionary = legacy_file.data.duplicate(true)
    legacy_world.load_chunks_old(legacy_file)
    check(not legacy_world.region_checkpoint_load_failed, "actual plain-gate loader migration succeeds")
    check(legacy_register.get_data("pocket_owner_key") == "bob", "plain gate consumes Alice to Bob handoff")
    var native_legacy: Dictionary = {}
    legacy_world.save_data(native_legacy, "check_")
    check(native_legacy["check_world"]["check_chunk_block"][Vector3i(-16, 0, 0)][0] == selected_id, "actual legacy native load selects Bob over plain")
    legacy_world.clear_old_chunk_data(legacy_file, legacy_world.Dimension.POCKET)
    check(legacy_file.data == originals, "clear_old retains source and destination keys")
    var durable: Dictionary = legacy_world.region_checkpoint_store.read_regions(legacy_world.fixture_root, "pocket__bob", manager.ids)
    native_world.clear_save_data()
    native_world.load_region(durable["regions"][Vector3i(-1, 0, 0)])
    var reloaded: Dictionary = {}
    native_world.save_data(reloaded, "check_")
    check(reloaded["check_world"]["check_chunk_block"][Vector3i(-16, 0, 0)][0] == selected_id, "legacy IDs survive durable native reload")
    legacy_file.data.merge(pure.legacy("pocket__carol", other_id))
    legacy_world.queue_dimension_instance(3, "carol")
    legacy_world.load_chunk_data(legacy_world.fixture_root)
    check(legacy_register.get_data("pocket_owner_key") == "carol" and not legacy_world.region_checkpoint_load_failed, "actual owner-prefixed fallback consumes handoff")
    legacy_file.data.merge(pure.legacy("pocket__dave", selected_id))
    var before_failed: Dictionary = legacy_file.data.duplicate(true)
    legacy_world.region_checkpoint_store = FailStore.new()
    legacy_world.queue_dimension_instance(3, "dave")
    legacy_world.load_chunks_old(legacy_file)
    check(legacy_world.region_checkpoint_load_failed, "migration write failure reported")
    check(legacy_register.get_data("pocket_owner_key") == "carol", "failed migration restores source owner")
    var unchanged: Dictionary = {}
    legacy_world.save_data(unchanged, "check_")
    check(unchanged["check_world"]["check_chunk_block"][Vector3i(-16, 0, 0)][0] == other_id, "failed migration preserves live native state")
    legacy_world.clear_old_chunk_data(legacy_file, legacy_world.Dimension.POCKET)
    legacy_world.save_chunk_data(legacy_world.fixture_root)
    check(legacy_file.data == before_failed and not legacy_world.region_checkpoint_store.has_checkpoint(legacy_world.fixture_root, "pocket__dave"), "failed migration preserves originals and cannot save blank world")
    manager.region_checkpoint = FailStore.new()
    var queued_before: Dictionary = Ref.world.pending_dimension_instance.duplicate(true)
    check(not manager._queue_loaded_dimension_instance(3, "dave"), "migration preflight refuses transition before disposal")
    check(Ref.world.pending_dimension_instance == queued_before, "failed preflight preserves outgoing instance")
    var prior_world = Ref.world
    Ref.world = legacy_world
    check(not manager._checkpoint_local_host_world(), "failed migration blocks host disposal checkpoint")
    Ref.world = prior_world
    legacy_world.region_checkpoint_store = load("res://coop_mod/region_checkpoint.gd").new()
    legacy_file.data.merge(pure.legacy("naraka", selected_id))
    legacy_world.current_dimension = 2
    legacy_world.queue_dimension_instance(2, "")
    legacy_world.load_chunks_old(legacy_file)
    check(legacy_register.get_data("pocket_owner_key") == "" and not legacy_world.region_checkpoint_load_failed, "public plain legacy handoff clears private owner")
    check(legacy_world.region_checkpoint_store.has_checkpoint(legacy_world.fixture_root, "naraka"), "public legacy durably converted")
    Ref.save_file_manager.loaded_file_register = old_register
    Ref.save_file_manager.loaded_file = old_file
    legacy_world.free()
    native_world.free()
    manager.free()
    pure.free()
    print("REGION_RUNTIME_RESULT ", checks, " checks ", failures, " failures")
    return failures
