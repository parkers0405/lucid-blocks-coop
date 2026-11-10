extends Node

class LocalWorld extends World:
    var center: Vector3
    var load_enabled: bool = true
    var simulate_enabled: bool = false
    func _physics_process(_delta: float) -> void:
        if load_enabled:
            set_loaded_region_center(center)

class Manager extends "res://coop_mod/coop_manager.gd":
    var fixture_world: World
    func _canonical_world():
        return fixture_world
    func _ready() -> void:
        pass
    func _physics_process(_delta: float) -> void:
        pass
    func _can_sample_player() -> bool:
        return fixture_world != null and fixture_world.load_enabled
    func get_active_dimension_instance_key() -> String:
        return "naraka" if _can_sample_player() else ""

var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("CANONICAL_RUNTIME_FAIL ", label)

func _world(viewport: SubViewport, center: Vector3, region: Dictionary) -> LocalWorld:
    var world := LocalWorld.new()
    world.process_mode = Node.PROCESS_MODE_ALWAYS
    world.center = center
    viewport.add_child(world)
    world.instance_radius = 16
    world.set_block_types(Ref.world.get_block_types())
    for property in ["block_material", "transparent_block_material", "foliage_material", "water_material", "water_surface_material"]:
        world.set(property, Ref.world.get(property))
    world.generator = ResourceLoader.load("res://main/world/generators/flat_generator.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
    world.start_up()
    world.load_region(region)
    world.initialize()
    return world

func run() -> int:
    if not FileAccess.file_exists(OS.get_executable_path().get_base_dir().path_join(".coop-test-runtime")):
        print("CANONICAL_RUNTIME_FAIL disposable runtime required")
        return 1
    var viewport := SubViewport.new()
    viewport.own_world_3d = true
    add_child(viewport)
    var solid: int = -1
    for block in Ref.world.get_block_types():
        if block.id > 1 and not block.foliage and not block.no_collision_block and block.living_block_path.is_empty():
            solid = block.id
            break
    if solid < 0:
        viewport.free()
        return 1
    var blocks := PackedInt32Array()
    blocks.resize(4096)
    blocks[0] = solid
    var fluid := PackedByteArray()
    fluid.resize(4096)
    var awake := PackedByteArray()
    awake.resize(64)
    var host_region: Dictionary = {"chunk_block": {Vector3i.ZERO: blocks}, "chunk_water": {Vector3i.ZERO: fluid}, "chunk_water_awake": {Vector3i.ZERO: awake}, "chunk_fire": {Vector3i.ZERO: fluid}}
    var guest_chunk := Vector3i(1024, 0, 0)
    var guest_region: Dictionary = {}
    for channel in host_region:
        guest_region[channel] = {guest_chunk: host_region[channel][Vector3i.ZERO].duplicate()}
    guest_region["chunk_water"][guest_chunk][9] = 4
    var host := _world(viewport, Vector3.ZERO, host_region)
    var guest := _world(viewport, Vector3(guest_chunk), guest_region)
    var deadline: int = Time.get_ticks_msec() + 15000
    while (not host.is_all_loaded() or not guest.is_all_loaded()) and Time.get_ticks_msec() < deadline:
        host.set_loaded_region_center(host.center)
        guest.set_loaded_region_center(guest.center)
        await get_tree().process_frame
    if not host.is_all_loaded() or not guest.is_all_loaded():
        print("CANONICAL_RUNTIME_FAIL load deadline; terminating owned disposable process")
        OS.kill(OS.get_process_id())
        return 1
    check(host.is_position_loaded(Vector3(0.5, 0.5, 0.5)), "host local bubble loaded")
    check(guest.is_position_loaded(Vector3(1024.5, 0.5, 0.5)), "distant guest bubble loaded")
    check(not host.is_position_loaded(Vector3(1024.5, 0.5, 0.5)) and not guest.is_position_loaded(Vector3(0.5, 0.5, 0.5)), "local centers remain independent without native modifications")
    var manager := Manager.new()
    add_child(manager)
    manager.terrain_epoch = "fixture"
    manager.fixture_world = guest
    var root: Dictionary = {}
    for channel in guest_region:
        root["naraka_" + channel] = guest_region[channel].duplicate(true)
    root["naraka_chunk_block"][guest_chunk][1] = solid
    root["naraka_chunk_water"][guest_chunk][2] = 4
    root["naraka_chunk_block"][guest_chunk][8] = solid
    root["naraka_chunk_water"][guest_chunk][9] = 0
    root["naraka_chunk_fire"][guest_chunk][8] = 5
    var patch: Dictionary = {"epoch": "fixture", "dimension": 2, "pocket_owner_key": "", "dimension_instance_key": "naraka", "world_data": {"naraka_world": root}}
    guest.force_reload()
    var applied: bool = await manager._apply_canonical_terrain(patch)
    check(applied, "canonical application explicitly confirms installed data")
    check(guest.is_all_loaded() and guest.load_enabled and not manager.canonical_apply_busy, "canonical application drains loader then restores processing")
    check(guest.get_block_type_at(Vector3(1025.5, 0.5, 0.5)).id == solid, "canonical terrain updates actual loaded voxel")
    check(guest.get_water_level_at(Vector3(1026.5, 0.5, 0.5)) == 4, "canonical water applied")
    check(guest.get_fire_at(Vector3(1032.5, 0.5, 0.5)) == 5, "canonical fire applied after neighboring water removal")
    manager.canonical_apply_busy = true
    check(not await manager._apply_canonical_terrain(patch), "queued application never acknowledges installation")
    await manager._apply_canonical_terrain(patch)
    check(manager.pending_canonical_patches.size() == 1, "busy canonical application coalesces updates without loss")
    manager.terrain_epoch = "replacement"
    var queued: Dictionary = manager.pending_canonical_patches.pop_front()
    check(not await manager._apply_canonical_terrain(queued), "old epoch cannot report successful application")
    check(manager.pending_canonical_patches.is_empty(), "old-session queued update rejected before requeue or native mutation")
    manager.canonical_apply_busy = false
    manager.free()
    host.load_enabled = false
    guest.load_enabled = false
    host.clear()
    guest.clear()
    await get_tree().process_frame
    viewport.free()
    print("CANONICAL_RUNTIME_RESULT ", checks, " checks ", failures, " failures")
    return failures
