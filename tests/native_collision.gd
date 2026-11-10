extends Node

func run() -> int:
    if not FileAccess.file_exists(OS.get_executable_path().get_base_dir().path_join(".coop-test-runtime")):
        print("NATIVE_COLLISION_FAIL disposable runtime marker required")
        return 1
    var viewport := SubViewport.new()
    viewport.own_world_3d = true
    add_child(viewport)
    var world = ClassDB.instantiate("World")
    viewport.add_child(world)
    world.instance_radius = 16
    world.set_block_types(Ref.world.get_block_types())
    for property in ["block_material", "transparent_block_material", "foliage_material", "water_material", "water_surface_material"]:
        world.set(property, Ref.world.get(property))
    world.generator = ResourceLoader.load("res://main/world/generators/flat_generator.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
    world.start_up()
    var solid_id: int = -1
    for block in world.get_block_types():
        if block.id > 1 and not block.foliage and not block.no_collision_block and block.living_block_path.is_empty():
            solid_id = block.id
            break
    if solid_id < 0:
        print("NATIVE_COLLISION_FAIL no solid fixture block")
        viewport.free()
        return 1
    var blocks := PackedInt32Array()
    blocks.resize(4096)
    blocks[0] = solid_id
    var fluid := PackedByteArray()
    fluid.resize(4096)
    var awake := PackedByteArray()
    awake.resize(64)
    world.load_region({"chunk_block": {Vector3i.ZERO: blocks}, "chunk_water": {Vector3i.ZERO: fluid}, "chunk_water_awake": {Vector3i.ZERO: awake}, "chunk_fire": {Vector3i.ZERO: fluid}})
    world.initialize()
    var deadline: int = Time.get_ticks_msec() + 10000
    while not world.is_all_loaded() and Time.get_ticks_msec() < deadline:
        world.set_loaded_region_center(Vector3.ZERO)
        await get_tree().process_frame
    if not world.is_all_loaded() or not world.is_position_loaded(Vector3(0.5, 0.5, 0.5)):
        _abort_incomplete_load()
        return 1
    var paused_before: bool = get_tree().paused
    get_tree().paused = false
    await get_tree().physics_frame
    await get_tree().physics_frame
    await get_tree().process_frame
    var query := PhysicsRayQueryParameters3D.create(Vector3(0.5, 2, 0.5), Vector3(0.5, -1, 0.5), 1)
    var hit: Dictionary = viewport.find_world_3d().direct_space_state.intersect_ray(query)
    get_tree().paused = paused_before
    var failures: int = 0
    if world.get_block_type_at(Vector3(0.5, 0.5, 0.5)).id != solid_id or not world.is_block_solid_at(Vector3(0.5, 0.5, 0.5)):
        print("NATIVE_COLLISION_FAIL loaded block identity/solidity")
        failures += 1
    if hit.is_empty() or not hit.position.is_equal_approx(Vector3(0.5, 1, 0.5)) or not hit.normal.is_equal_approx(Vector3.UP):
        print("NATIVE_COLLISION_FAIL native voxel top-face ray hit=", hit)
        failures += 1
    query.from = Vector3(2.5, 2, 2.5)
    # Keep the air query in the seeded chunk, above neighboring generated ground at y=0.
    query.to = Vector3(2.5, 0.1, 2.5)
    var air_hit: Dictionary = viewport.find_world_3d().direct_space_state.intersect_ray(query)
    if not air_hit.is_empty():
        print("NATIVE_COLLISION_FAIL air ray unexpectedly blocked: block_id=", world.get_block_type_at(Vector3(2.5, 0.5, 2.5)).id, " hit=", air_hit)
        failures += 1
    world.clear()
    await get_tree().process_frame
    viewport.free()
    print("NATIVE_COLLISION_RESULT 3 checks ", failures, " failures")
    return failures

func _abort_incomplete_load() -> void:
    # Native worker jobs may still hold World pointers; skip unsafe scene teardown on failure.
    print("NATIVE_COLLISION_FAIL terrain loading deadline; terminating disposable process")
    OS.kill(OS.get_process_id())
