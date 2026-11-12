class_name LucidBlocksWorld extends World


const RegionCheckpoint = preload("res://coop_mod/region_checkpoint.gd")
var pending_dimension_instance: Dictionary = {}
var region_checkpoint_load_failed: bool = false
var region_checkpoint_store = RegionCheckpoint.new()


@export_group("Editor Debug")
@export var debug_extents: Vector3i = Vector3i(64, 64, 64)
@export var raster_block_type: Block
@export var cutscene_block_type: Block
@export var decoration_to_edit_path: String
@export var decoration_to_save_path: String
@export var fill_with_void: bool = false

@onready var spawn_tester: SpawnTester = %SpawnTester

signal start_up_done


enum Dimension { DEBUG = 0, CREATIVE = 1, NARAKA = 2, POCKET = 3, CHALLENGE = 4, FIRMAMENT = 5, YHVH = 6, ALMA = 7, LUCY = 8, TORUS = 9 }
var current_dimension: Dimension = Dimension.NARAKA


var respawn_positions: Dictionary[Vector3i, bool]


var load_enabled: bool = false
var simulate_enabled: bool = false
var started_up: bool = false
var simulate_frame: bool = true
var buffer_instance_radius: int = 80

var fps_cap: int = 60
var current_seed: int
var even: bool = false
var coop_perf_override_active: bool = false
var coop_dynamic_visual_refresh_frames: int = 0
var coop_original_os_low_processor_mode_set: bool = false
var coop_original_os_low_processor_mode: bool = false
var coop_original_os_low_processor_sleep_usec_set: bool = false
var coop_original_os_low_processor_sleep_usec: int = 0

var environment_speed_multiplier: float = 1.0


func _ready() -> void :
    print("World children ready.")
    if not Ref.player_fuser.fusion_table_loaded:
        await Ref.player_fuser.fusion_table_done_loading

    # Native chunk workers index this array mutably; keep their copy unshared.
    set_fusion_table(Ref.player_fuser.fusion_table.duplicate(), Ref.player_fuser.fusion_table_width)
    Ref.save_file_manager.settings_updated.connect(_on_settings_updated)
    Ref.player.get_node("%Curse").delusion_changed.connect(_on_delusion_updated)
    Ref.sky.sky_tint_updated.connect(_on_sky_tint_updated)
    start_up()

    _on_settings_updated()

    start_up_done.emit()
    started_up = true

    print("World ready.")


func _on_sky_tint_updated(new_tint: Color) -> void :
    water_material.set_shader_parameter("sky_tint", new_tint)
    water_surface_material.set_shader_parameter("sky_tint", new_tint)
    Ref.water_filter.color = Ref.water_filter.base_color.lerp(new_tint, 0.2)


func _on_delusion_updated(new_value: float) -> void :
    block_material.set_shader_parameter("drug", new_value)
    foliage_material.set_shader_parameter("drug", new_value)


func _on_settings_updated() -> void :
    instance_radius = int(Ref.save_file_manager.settings_file.get_data("render_distance", 80.0))
    Ref.world.force_reload()
    RenderingServer.viewport_set_scaling_3d_scale(get_viewport().get_viewport_rid(), Ref.save_file_manager.settings_file.get_data("render_scale", 100) / 100.0)
    _apply_frame_pacing_settings()


func _is_coop_perf_override_active() -> bool:
    return Ref.coop_manager != null and Ref.coop_manager.has_method("has_active_session") and Ref.coop_manager.has_active_session()


func _should_force_background_perf_override() -> bool:
    return coop_perf_override_active and not DisplayServer.window_is_focused()


func _apply_background_cpu_override(active: bool) -> void:
    if not (OS is Object):
        return

    if active:
        if not coop_original_os_low_processor_mode_set:
            coop_original_os_low_processor_mode = bool(OS.get("low_processor_usage_mode"))
            coop_original_os_low_processor_mode_set = true
        if not coop_original_os_low_processor_sleep_usec_set:
            coop_original_os_low_processor_sleep_usec = int(OS.get("low_processor_usage_mode_sleep_usec"))
            coop_original_os_low_processor_sleep_usec_set = true
        OS.set("low_processor_usage_mode", false)
        OS.set("low_processor_usage_mode_sleep_usec", 0)
        return

    if coop_original_os_low_processor_mode_set:
        OS.set("low_processor_usage_mode", coop_original_os_low_processor_mode)
    if coop_original_os_low_processor_sleep_usec_set:
        OS.set("low_processor_usage_mode_sleep_usec", coop_original_os_low_processor_sleep_usec)


func _should_force_background_dynamic_ticks() -> bool:
    return _should_force_background_perf_override()


func _apply_frame_pacing_settings() -> void:
    coop_perf_override_active = _is_coop_perf_override_active()
    var background_override_active: bool = _should_force_background_perf_override()
    _apply_background_cpu_override(background_override_active)
    process_mode = Node.PROCESS_MODE_ALWAYS if coop_perf_override_active else Node.PROCESS_MODE_INHERIT
    if background_override_active:
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
        fps_cap = 0
        Engine.max_fps = 0
        return

    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if Ref.save_file_manager.settings_file.get_data("vsync_enabled", true) else DisplayServer.VSYNC_DISABLED)
    fps_cap = Ref.save_file_manager.settings_file.get_data("fps_cap", 60)
    Engine.max_fps = fps_cap


func refresh_multiplayer_runtime_mode() -> void:
    _apply_frame_pacing_settings()


func _notification(what: int) -> void :
    match what:
        MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
            if _is_coop_perf_override_active():
                _apply_frame_pacing_settings()
            else:
                Engine.max_fps = 15
        MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN:
            _apply_frame_pacing_settings()


func _physics_process(_delta: float) -> void :
    if load_enabled:
        even = not even
        set_loaded_region_center(Ref.player.global_position)

        var pause_blocks_sim: bool = get_tree().paused and not _is_coop_perf_override_active()
        var allow_dynamic_tick: bool = simulate_frame or _should_force_background_dynamic_ticks()
        if simulate_enabled and not pause_blocks_sim and allow_dynamic_tick and not (even and Ref.sun.target_time_scale < 1.0):
            simulate_dynamic()
            if not _should_force_background_dynamic_ticks():
                simulate_frame = false


func uses_coop_multi_region_loading() -> bool:
    return false


func _process(_delta: float) -> void :
    simulate_frame = true
    var coop_override_now: bool = _is_coop_perf_override_active()
    if coop_override_now != coop_perf_override_active:
        _apply_frame_pacing_settings()


func _is_guest_visual_refresh_needed() -> bool:
    return Ref.coop_manager != null and Ref.coop_manager.is_client_session() and not simulate_enabled


func queue_coop_dynamic_visual_refresh(frame_count: int = 4) -> void:
    if not _is_guest_visual_refresh_needed():
        return
    coop_dynamic_visual_refresh_frames = maxi(coop_dynamic_visual_refresh_frames, frame_count)


func _input(event: InputEvent) -> void :
    if Ref.main.debug and event.is_action_pressed("debug_capture", false):
        capture_decoration()
    if Ref.main.debug and event.is_action_pressed("debug_rasterize", false):
        rasterize()


func make_environment_changes_instant() -> void :
    environment_speed_multiplier = 10000


func make_environment_changes_normal() -> void :
    environment_speed_multiplier = 1


func sort_by_id(a: Block, b: Block) -> bool:
    if not a.textureless and b.textureless:
        return true
    return a.id < b.id


func reload_types() -> void :
    var stack: Array[String] = ["res://main/world/decorations/", "res://main/plot/cutscenes/challenge_cutscene/"]

    var block_types: Array[Block] = []
    var decorations: Array[Decoration] = []

    print("Loading decorations...")

    while stack.size() > 0:
        var dir: DirAccess = DirAccess.open(stack.pop_back())
        dir.list_dir_begin()
        var file_name: String = dir.get_next()
        while file_name != "":
            var path: String = dir.get_current_dir() + "/" + file_name
            if dir.dir_exists(path):
                stack.append(path)
            else:
                if ".tres" in path:
                    path = path.replace(".remap", "")
                    var resource: Resource = ResourceLoader.load(path)
                    if resource is Decoration:
                        decorations.append(resource)
            file_name = dir.get_next()

    print("Decorations loaded.")

    for id in ItemMap.all_item_ids:
        var item: Item = ItemMap.map(id)
        if item is Block:
            block_types.append(item)

    block_types.sort_custom(sort_by_id)

    set_block_types(block_types)
    set_decorations(decorations)


func capture_decoration() -> void :
    if not load_enabled:
        return

    var new_decoration: Decoration
    if decoration_to_edit_path != "":
        new_decoration = load(decoration_to_edit_path).duplicate()
    else:
        new_decoration = SimpleDecoration.new()

    var min_corner: Vector3 = debug_extents
    var max_corner: Vector3 = Vector3()

    var min_corner_void: Vector3 = debug_extents
    var max_corner_void: Vector3 = Vector3()

    for y in range(0, debug_extents.y):
        for z in range(0, debug_extents.z):
            for x in range(0, debug_extents.x):
                if not is_position_loaded(Vector3(x, y, z)):
                    continue
                var block: Block = get_block_type_at(Vector3(x, y, z))

                if block.id != 0 and block.id != 432238:
                    min_corner.x = min(x, min_corner.x)
                    min_corner.y = min(y, min_corner.y)
                    min_corner.z = min(z, min_corner.z)
                    max_corner.x = max(x, max_corner.x)
                    max_corner.y = max(y, max_corner.y)
                    max_corner.z = max(z, max_corner.z)
                if block.id == 1:
                    min_corner_void.x = min(x, min_corner_void.x)
                    min_corner_void.y = min(y, min_corner_void.y)
                    min_corner_void.z = min(z, min_corner_void.z)
                    max_corner_void.x = max(x, max_corner_void.x)
                    max_corner_void.y = max(y, max_corner_void.y)
                    max_corner_void.z = max(z, max_corner_void.z)

    max_corner_void += Vector3(1, 1, 1)
    max_corner += Vector3(1, 1, 1)

    var blocks: PackedInt32Array = PackedInt32Array()

    new_decoration.size = max_corner - min_corner
    blocks.resize(int(new_decoration.size.x * new_decoration.size.y * new_decoration.size.z))

    for y in range(min_corner.y, max_corner.y):
        for z in range(min_corner.z, max_corner.z):
            for x in range(min_corner.x, max_corner.x):
                if not is_position_loaded(Vector3(x, y, z)):
                    continue
                var block: Block = get_block_type_at(Vector3(x, y, z))
                var i: int = int((x - min_corner.x) + new_decoration.size.x * (z - min_corner.z) + new_decoration.size.x * new_decoration.size.z * (y - min_corner.y))
                if fill_with_void and (block.id == 0 and y >= min_corner_void.y and y < max_corner_void.y and x >= min_corner_void.x and x < max_corner_void.x and z >= min_corner_void.z and z < max_corner_void.z):
                    blocks[i] = 1
                else:
                    blocks[i] = block.id

                if block.id == cutscene_block_type.id:
                    new_decoration.cutscene_block_position = Vector3i(x - int(min_corner.x), y - int(min_corner.y), z - int(min_corner.z))
                    new_decoration.has_cutscene_block = true

    new_decoration.blocks = blocks

    if decoration_to_save_path == "":
        var id: int = randi_range(10000, 90000)
        ResourceSaver.save(new_decoration, "res://main/world/decorations/new_deco%d.tres" % id)
        print("decoration %d saved" % id)
    else:
        ResourceSaver.save(new_decoration, decoration_to_save_path)
        print("decoration %s saved" % decoration_to_save_path)


func load_decoration(decoration: Decoration) -> void :
    for y in range(0, decoration.size.y):
        for z in range(0, decoration.size.z):
            for x in range(0, decoration.size.x):
                if not is_position_loaded(Vector3(2 + x, y, 2 + z)):
                    continue
                var block: Block = ItemMap.map(decoration.blocks[x + z * decoration.size.x + y * decoration.size.x * decoration.size.z])
                place_block_at(Vector3(2 + x, y, 2 + z), block, false, false)


func rasterize() -> void :
    for y in range(0, debug_extents.y):
        for z in range(0, debug_extents.z):
            for x in range(0, debug_extents.x):
                var check_position: Vector3i = Vector3i(x, y, z)
                %RasterizeInsideChecker.global_position = check_position
                %RasterizeInsideChecker.force_shapecast_update()

                if %RasterizeInsideChecker.is_colliding():
                    if not is_position_loaded(check_position):
                        printerr("Position not loaded: ", check_position)
                        continue
                    place_block_at(check_position, raster_block_type, false, false)


func select_generator() -> void :
    match current_dimension:
        Dimension.NARAKA:
            generator = ResourceLoader.load("res://main/world/generators/main_generator.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
        Dimension.CREATIVE:
            generator = ResourceLoader.load("res://main/world/generators/flat_generator.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
        Dimension.DEBUG:
            generator = ResourceLoader.load("res://main/world/generators/debug_generator.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
        Dimension.POCKET:
            generator = ResourceLoader.load("res://main/world/generators/pocket_generator.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
        Dimension.CHALLENGE:
            generator = ResourceLoader.load("res://main/world/generators/challenge_generator.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
        Dimension.FIRMAMENT:
            generator = ResourceLoader.load("res://main/world/generators/firmament_generator.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
        Dimension.YHVH:
            generator = ResourceLoader.load("res://main/world/generators/yhvh_generator.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
        Dimension.ALMA:
            generator = ResourceLoader.load("res://main/world/generators/alma_generator.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
        Dimension.LUCY:
            generator = ResourceLoader.load("res://main/world/generators/lucy_generator.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
        Dimension.TORUS:
            generator = ResourceLoader.load("res://main/world/generators/torus_generator.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
        _:
            assert(false)
    generator.seed = current_seed


func queue_dimension_instance(dimension: int, owner: String) -> bool:
    if not SaveFile.DIMENSION_MAP.has(dimension):
        return false
    if dimension in [Dimension.POCKET, Dimension.FIRMAMENT] and not owner.is_empty() and not RegionCheckpoint.valid_component(owner):
        return false
    pending_dimension_instance = {"dimension": dimension, "owner": owner}
    return true


func apply_pending_dimension_instance(file_register: SaveFileRegister) -> bool:
    if pending_dimension_instance.is_empty() or pending_dimension_instance["dimension"] != current_dimension:
        return false
    var owner: String = pending_dimension_instance["owner"] if current_dimension in [Dimension.POCKET, Dimension.FIRMAMENT] else ""
    if not owner.is_empty() and not RegionCheckpoint.valid_component(owner):
        return false
    file_register.set_data("pocket_owner_key", owner, true)
    pending_dimension_instance.clear()
    return true


func _get_private_instance_owner_key() -> String:
    if current_dimension != Dimension.POCKET and current_dimension != Dimension.FIRMAMENT:
        return ""
    if Ref.save_file_manager == null or Ref.save_file_manager.loaded_file_register == null:
        return ""
    return str(Ref.save_file_manager.loaded_file_register.get_data("pocket_owner_key", "")).strip_edges()


func _get_dimension_save_namespace() -> String:
    var dimension_namespace: String = SaveFile.DIMENSION_MAP[current_dimension]
    var owner_key: String = _get_private_instance_owner_key()
    if owner_key != "":
        if not RegionCheckpoint.valid_component(owner_key):
            return ""
        dimension_namespace = "%s__%s" % [dimension_namespace, owner_key]
    return dimension_namespace


func get_region_file_name(region_coordinate: Vector3i) -> String:
    return "c%d.%d.%d.txt" % [region_coordinate.x, region_coordinate.y, region_coordinate.z]


func get_checkpoint_block_ids() -> Dictionary:
    var ids: Dictionary = {}
    for item_id in ItemMap.all_item_ids:
        if ItemMap.map(item_id) is Block:
            ids[item_id] = true
    return ids


func save_chunk_data(chunk_directory: String) -> void :
    if region_checkpoint_load_failed:
        push_warning("Region save refused after failed migration/load")
        return
    register_loaded_chunks()

    var dimension_folder: String = _get_dimension_save_namespace()
    if dimension_folder.is_empty():
        push_warning("Invalid private world owner; region save refused")
        return
    var store = RegionCheckpoint.new()
    if (Ref.coop_manager != null and Ref.coop_manager.has_active_session()) or not _get_private_instance_owner_key().is_empty() or store.has_checkpoint(chunk_directory, dimension_folder):
        var serialized: Dictionary = {}
        save_data(serialized, dimension_folder + "_")
        if Ref.coop_manager != null:
            serialized = Ref.coop_manager.filter_local_checkpoint(serialized, dimension_folder + "_")
        var committed: Dictionary = store.commit_patch(chunk_directory, dimension_folder, dimension_folder + "_", serialized, get_checkpoint_block_ids())
        if not committed["ok"]:
            push_error("Private region save failed: " + str(committed.get("error", "unknown error")))
        return
    var dimension_directory = chunk_directory + "/" + dimension_folder + "/"
    if not DirAccess.dir_exists_absolute(dimension_directory):
        var status: Error = DirAccess.make_dir_absolute(dimension_directory)
        assert (status == OK)

    var regions_to_save: Dictionary[Vector3i, bool] = get_regions_to_save()
    print("Regions to save: ", len(regions_to_save))
    for region_coordinate in regions_to_save:
        var region_file: FileAccess = FileAccess.open(dimension_directory + get_region_file_name(region_coordinate), FileAccess.WRITE)

        var region_file_data: Dictionary = get_region_data(region_coordinate)
        region_file_data["save_version"] = ProjectSettings.get_setting("application/config/version")
        region_file_data["coordinate"] = region_coordinate

        var json_string: String = JSON.stringify(JSON.from_native(region_file_data))
        var buffer: PackedByteArray = json_string.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
        var _buffer_saved: bool = region_file.store_buffer(buffer)


func _checkpoint_chunks_directory() -> String:
    var register = Ref.save_file_manager.loaded_file_register
    return Ref.save_file_manager.get_save_file_directory(str(register.get_data("uuid", "")), register.is_downloaded).path_join("chunks")


func _load_dimension_regions(chunk_directory: String, file: SaveFile) -> bool:
    if Ref.coop_manager != null and self == Ref.world:
        Ref.coop_manager.save_queue.flush()
    var register = Ref.save_file_manager.loaded_file_register
    var previous_owner: String = str(register.get_data("pocket_owner_key", "", true))
    var previous_pending: Dictionary = pending_dimension_instance.duplicate(true)
    var changed_owner: bool = apply_pending_dimension_instance(register)
    var dimension_folder: String = _get_dimension_save_namespace()
    var loaded: Dictionary = region_checkpoint_store.migrate_legacy(chunk_directory, dimension_folder, SaveFile.DIMENSION_MAP[current_dimension], file.data if file != null else {}, get_checkpoint_block_ids())
    if loaded["ok"]:
        loaded = region_checkpoint_store.read_regions(chunk_directory, dimension_folder, get_checkpoint_block_ids())
    if not loaded["ok"]:
        register.set_data("pocket_owner_key", previous_owner, true)
        pending_dimension_instance = previous_pending
        region_checkpoint_load_failed = true
        push_warning("Region migration/load refused: " + str(loaded.get("error", "unknown error")))
        return false
    region_checkpoint_load_failed = false
    if Ref.coop_manager != null and self == Ref.world:
        if not Ref.coop_manager.prepare_instance_preserved_state(file, int(current_dimension), _get_private_instance_owner_key(), previous_owner):
            register.set_data("pocket_owner_key", previous_owner, true)
            pending_dimension_instance = previous_pending
            region_checkpoint_load_failed = true
            return false
    select_generator()
    for region in loaded["regions"].values():
        load_region(region)
    if changed_owner:
        Ref.save_file_manager.write_register_file(register)
    return true


func load_chunk_data(chunk_directory: String) -> void :
    _load_dimension_regions(chunk_directory, Ref.save_file_manager.loaded_file)


func load_chunks_old(file: SaveFile) -> void :
    _load_dimension_regions(_checkpoint_chunks_directory(), file)


func clear_old_chunk_data(_file: SaveFile, _dimension: Dimension) -> void :
    # Keep the old data so a failed migration can be recovered.
    pass

func save_file(file: SaveFile) -> void :
    var owner_key: String = _get_private_instance_owner_key()
    if owner_key != "":
        file.set_data("%s/respawn_positions" % _get_dimension_save_namespace(), respawn_positions.duplicate(true), true)
    else:
        file.set_data("respawn_positions", respawn_positions)


func load_file(file: SaveFile) -> void :
    var default_positions: Dictionary[Vector3i, bool] = {}
    var owner_key: String = _get_private_instance_owner_key()
    if owner_key != "":
        var manager = _respawn_manager()
        # The earlier load step must prove who owns an old unqualified map.
        var result: Dictionary
        if manager != null:
            result = manager.read_private_respawns(file.data, int(current_dimension), owner_key, "__unproven__")
        else:
            result = {"ok": true, "positions": file.get_data("%s/respawn_positions" % _get_dimension_save_namespace(), default_positions, true)}
        if not result["ok"]:
            region_checkpoint_load_failed = true
            return
        var positions: Dictionary[Vector3i, bool] = {}
        positions.assign(result["positions"])
        respawn_positions = positions
    else:
        var positions: Dictionary[Vector3i, bool] = {}
        positions.assign(file.get_data("respawn_positions", default_positions))
        respawn_positions = positions

func _respawn_manager():
    return Ref.coop_manager


func load_file_register(file_register: SaveFileRegister) -> void :
    current_seed = file_register.get_data("world_seed", 0)
    current_dimension = file_register.get_data("dimension", Dimension.CREATIVE if Ref.main.creative else Dimension.NARAKA, true)


func save_file_register(file_register: SaveFileRegister) -> void :
    file_register.set_data("dimension", current_dimension, true)
