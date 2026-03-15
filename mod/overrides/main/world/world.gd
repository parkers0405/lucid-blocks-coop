class_name LucidBlocksWorld extends World


@export_group("Editor Debug")
@export var debug_extents: Vector3i = Vector3i(64, 64, 64)
@export var raster_block_type: Block
@export var cutscene_block_type: Block
@export var decoration_to_edit_path: String
@export var decoration_to_save_path: String
@export var fill_with_void: bool = false

@onready var spawn_tester: SpawnTester = %SpawnTester

signal start_up_done


enum Dimension { DEBUG = 0, CREATIVE = 1, NARAKA = 2, POCKET = 3, CHALLENGE = 4, FIRMAMENT = 5, YHVH = 6 }
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
var session_region_anchor_index: int = 0
var session_region_anchor_hold_frames: int = 0
var session_region_last_chunk_centers: Array = []

var environment_speed_multiplier: float = 1.0
const SESSION_RADIUS_QUANTUM: int = 16
const SESSION_ANCHOR_SETTLE_FRAMES: int = 12
const SESSION_ANCHOR_IDLE_ROTATE_FRAMES: int = 18


func _ready() -> void :
    print("World children ready.")
    if not Ref.player_fuser.fusion_table_loaded:
        await Ref.player_fuser.fusion_table_done_loading

    set_fusion_table(Ref.player_fuser.fusion_table, Ref.player_fuser.fusion_table_width)
    start_up()

    Ref.save_file_manager.settings_updated.connect(_on_settings_updated)
    Ref.player.get_node("%Curse").delusion_changed.connect(_on_delusion_updated)
    Ref.sky.sky_tint_updated.connect(_on_sky_tint_updated)
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

    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if Ref.save_file_manager.settings_file.get_data("vsync_enabled", true) else DisplayServer.VSYNC_DISABLED)
    fps_cap = Ref.save_file_manager.settings_file.get_data("fps_cap", 60)
    Engine.max_fps = fps_cap


func _notification(what: int) -> void :
    match what:
        MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
            Engine.max_fps = 15
        MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN:
            Engine.max_fps = fps_cap


func _physics_process(_delta: float) -> void :
    if load_enabled:
        even = not even
        var load_center: Vector3 = Ref.player.global_position
        if _should_use_host_multi_region_loading() and has_method("set_loaded_region_centers") and Ref.coop_manager != null:
            var session_positions: Array = Ref.coop_manager.get_same_instance_session_positions()
            if not session_positions.is_empty():
                call("set_loaded_region_centers", session_positions)
            else:
                set_loaded_region_center(load_center)
        else:
            if Ref.coop_native_patch != null and Ref.coop_native_patch.has_method("clear_active_region_centers"):
                Ref.coop_native_patch.call("clear_active_region_centers")
            if Ref.coop_manager != null:
                load_center = Ref.coop_manager.get_world_load_center(load_center)
            set_loaded_region_center(load_center)

        if simulate_enabled and not get_tree().paused and simulate_frame and not (even and Ref.sun.target_time_scale < 1.0):
            simulate_dynamic()
            simulate_frame = false


func set_loaded_region_centers(centers: Array) -> void:
    var active_centers: Array = []
    for center in centers:
        if center is Vector3:
            active_centers.append(center)

    var dirty_indices: Array = _update_session_region_tracking(active_centers)

    if Ref.coop_native_patch != null:
        if active_centers.is_empty() and Ref.coop_native_patch.has_method("clear_active_region_centers"):
            Ref.coop_native_patch.call("clear_active_region_centers")
        elif Ref.coop_native_patch.has_method("set_active_region_centers"):
            Ref.coop_native_patch.call("set_active_region_centers", active_centers)

    if active_centers.is_empty():
        session_region_anchor_index = 0
        session_region_anchor_hold_frames = 0
        session_region_last_chunk_centers.clear()
        set_loaded_region_center(Ref.player.global_position)
        return

    var base_radius: int = _get_session_base_instance_radius()
    var desired_radius: int = _quantize_session_radius(base_radius)
    desired_radius = mini(desired_radius, _get_native_instance_radius_cap())
    desired_radius = maxi(desired_radius, SESSION_RADIUS_QUANTUM)
    desired_radius = maxi(desired_radius, base_radius)

    if instance_radius != desired_radius:
        instance_radius = desired_radius
        force_reload()

    set_loaded_region_center(_get_next_session_anchor_center(active_centers, dirty_indices))


func _should_use_host_multi_region_loading() -> bool:
    return multiplayer != null and multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func _get_session_base_instance_radius() -> int:
    if Ref.save_file_manager != null and Ref.save_file_manager.settings_file != null:
        return maxi(16, int(Ref.save_file_manager.settings_file.get_data("render_distance", 80.0)))
    return maxi(16, int(instance_radius))


func _get_next_session_anchor_center(active_centers: Array, dirty_indices: Array) -> Vector3:
    if active_centers.size() == 1:
        session_region_anchor_index = 0
        session_region_anchor_hold_frames = SESSION_ANCHOR_SETTLE_FRAMES
        return active_centers[0]

    if session_region_anchor_index >= active_centers.size():
        session_region_anchor_index = 0

    if dirty_indices.has(session_region_anchor_index):
        session_region_anchor_hold_frames = SESSION_ANCHOR_SETTLE_FRAMES
        return active_centers[session_region_anchor_index]

    if not is_all_loaded():
        session_region_anchor_hold_frames = SESSION_ANCHOR_SETTLE_FRAMES
        return active_centers[session_region_anchor_index]

    if session_region_anchor_hold_frames > 0:
        session_region_anchor_hold_frames -= 1
        return active_centers[session_region_anchor_index]

    if not dirty_indices.is_empty():
        session_region_anchor_index = int(dirty_indices[0])
        session_region_anchor_hold_frames = SESSION_ANCHOR_SETTLE_FRAMES
        return active_centers[session_region_anchor_index]

    session_region_anchor_index = (session_region_anchor_index + 1) % active_centers.size()
    session_region_anchor_hold_frames = SESSION_ANCHOR_IDLE_ROTATE_FRAMES
    return active_centers[session_region_anchor_index]


func _update_session_region_tracking(active_centers: Array) -> Array:
    var dirty_indices: Array = []
    var snapped_centers: Array = []
    for i in range(active_centers.size()):
        var snapped_center: Vector3i = snap_to_chunk(active_centers[i])
        snapped_centers.append(snapped_center)
        if i >= session_region_last_chunk_centers.size() or session_region_last_chunk_centers[i] != snapped_center:
            dirty_indices.append(i)

    if active_centers.size() != session_region_last_chunk_centers.size():
        for i in range(active_centers.size()):
            if not dirty_indices.has(i):
                dirty_indices.append(i)

    session_region_last_chunk_centers = snapped_centers
    if session_region_anchor_index >= active_centers.size():
        session_region_anchor_index = 0
        session_region_anchor_hold_frames = 0

    return dirty_indices


func _get_native_instance_radius_cap() -> int:
    var cap: int = maxi(maxi(_get_session_base_instance_radius(), int(instance_radius)), 96)
    if Ref.coop_native_patch == null or not Ref.coop_native_patch.has_method("get_status"):
        return cap

    var status_variant: Variant = Ref.coop_native_patch.call("get_status")
    if typeof(status_variant) != TYPE_DICTIONARY:
        return cap

    var status: Dictionary = status_variant
    return maxi(cap, int(status.get("current_instance_radius_cap", cap)))


func _quantize_session_radius(radius: int) -> int:
    return maxi(SESSION_RADIUS_QUANTUM, int(ceili(float(radius) / float(SESSION_RADIUS_QUANTUM))) * SESSION_RADIUS_QUANTUM)


func _process(_delta: float) -> void :
    simulate_frame = true


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
        _:
            assert(false)
    generator.seed = current_seed


func save_file(file: SaveFile) -> void :
    save_data(file.data, SaveFile.DIMENSION_MAP[current_dimension] + "_")
    file.set_data("respawn_positions", respawn_positions)


func load_file(file: SaveFile) -> void :
    select_generator()
    load_data(file.data, SaveFile.DIMENSION_MAP[current_dimension] + "_")

    var default_positions: Dictionary[Vector3i, bool] = {}
    respawn_positions = file.get_data("respawn_positions", default_positions)


func load_file_register(file_register: SaveFileRegister) -> void :
    current_seed = file_register.get_data("world_seed", 0)
    current_dimension = file_register.get_data("dimension", Dimension.CREATIVE if Ref.main.creative else Dimension.NARAKA, true)


func save_file_register(file_register: SaveFileRegister) -> void :
    file_register.set_data("dimension", current_dimension, true)
