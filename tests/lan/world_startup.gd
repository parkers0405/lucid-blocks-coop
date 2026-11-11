extends Node

var role: String
var scenario: String
var port: int
var seeded: bool = false
var stage: String = "startup"
var checks: int = 0
var failures: int = 0
var early_frames: int = 0
var last_radius: int = -1

func _enter_tree() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var args := OS.get_cmdline_user_args()
    role = args[0]
    scenario = args[1]
    port = int(args[2])
    get_tree().node_added.connect(_observe)
    get_tree().physics_frame.connect(_before_physics)
    _scan(get_tree().root)

func _ready() -> void:
    call_deferred("_run")

func _scan(node: Node) -> void:
    _observe(node)
    for child in node.get_children():
        _scan(child)

func _observe(node: Node) -> void:
    if node.get_script() == null:
        return
    var path: String = node.get_script().resource_path
    if path == "res://main/items/icon_generator/icon_generator.gd":
        node.skip = true
    elif path == "res://main/save_file/save_file_manager.gd":
        if node.is_node_ready():
            _seed(node)
        elif not node.ready.is_connected(_seed.bind(node)):
            node.ready.connect(_seed.bind(node), CONNECT_ONE_SHOT)

func _seed(files: Node) -> void:
    files.device_file.set_data("save_version", ProjectSettings.get_setting("application/config/version"))
    files.device_file.set_data("shaders_baked", true)
    files.device_file.set_data("tutorial", false)
    files.settings_file.set_data("render_distance", 16.0)
    files.settings_updated.connect(_settings_updated)
    seeded = true
    print("WORLD_STARTUP_SEEDED ", role)

func _settings_updated() -> void:
    _snapshot("settings_updated")

func _manager():
    # The original game has no co-op property.
    for property in Ref.get_property_list():
        if property["name"] == "coop_manager":
            return Ref.get("coop_manager")
    return null

func _snapshot(event: String) -> void:
    if Ref.world == null or Ref.player == null:
        return
    print("WORLD_STARTUP_STATE ", JSON.stringify({
        "role": role, "stage": stage, "event": event,
        "physics_frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(),
        "position": str(Ref.player.global_position), "radius": Ref.world.instance_radius,
        "buffer_radius": Ref.world.get("buffer_instance_radius"),
        "load_enabled": Ref.world.load_enabled, "all_loaded": Ref.world.is_all_loaded(),
        "simulate_enabled": Ref.world.simulate_enabled, "paused": get_tree().paused,
        "world_process_mode": Ref.world.process_mode, "player_disabled": Ref.player.disabled,
    }))

func _before_physics() -> void:
    if Ref.world == null or not Ref.world.load_enabled:
        return
    if int(Ref.world.instance_radius) != last_radius:
        last_radius = int(Ref.world.instance_radius)
        _snapshot("radius_changed_before_physics")
    if early_frames < 8:
        early_frames += 1
        _snapshot("before_initial_physics")

func _mark(name_value: String, value: Dictionary = {}) -> void:
    var target: String = scenario.path_join(role + "_" + name_value + ".json")
    var file := FileAccess.open(target + ".tmp", FileAccess.WRITE)
    file.store_string(JSON.stringify(value))
    file.flush()
    file.close()
    if DirAccess.rename_absolute(target + ".tmp", target) != OK:
        push_error("WORLD_STARTUP marker publication failed")

func _wait(predicate: Callable, label: String) -> bool:
    stage = label
    var deadline: int = Time.get_ticks_msec() + 60000
    while not predicate.call():
        if Time.get_ticks_msec() >= deadline:
            _check(false, "deadline " + label)
            return false
        await get_tree().create_timer(0.05, true, false, true).timeout
    return true

func _check(ok: bool, label: String) -> void:
    checks += 1
    print("WORLD_STARTUP_CHECK ", role, " ", "PASS " if ok else "FAIL ", label)
    if not ok:
        failures += 1
        _mark("failed", {"stage": stage, "label": label})

func _run() -> void:
    if not FileAccess.file_exists(scenario.path_join(".local-coop-scenario")):
        push_error("WORLD_STARTUP disposable marker missing")
        return
    if not await _wait(func(): return seeded and Ref.main != null and Ref.main.loaded, "menu"):
        return
    var files = Ref.save_file_manager
    files.initialize_file()
    var register = files.loaded_file_register
    var settings := {"dimension": 1, "divine": true, "progression_disabled": true, "world_seed": 12345, "find_spawn": false, "reset_world": false, "title": "Disposable world startup control"}
    for key in settings:
        register.set_data(key, settings[key], true)
    files.initialize_save_file_directory(register.get_data("uuid"), false)
    files.load_file(register)
    stage = "enter_game"
    _snapshot("before_enter_game")
    await Ref.main.enter_game()
    _snapshot("after_enter_game")
    _check(Ref.world.load_enabled and Ref.world.is_all_loaded() and not Ref.player.disabled, "actual creative world loaded")
    var loaded_radius: int = Ref.world.instance_radius
    var loaded_buffer_radius: int = Ref.world.buffer_instance_radius
    if role == "host":
        var manager = _manager()
        if manager == null:
            _check(false, "co-op manager exists")
            return
        for widget_name in ["port_input", "main_menu_coop_port_input", "pause_menu_coop_port_input"]:
            var widget = manager.get(widget_name)
            if is_instance_valid(widget):
                widget.value = port
                widget.get_line_edit().text = str(port)
        _snapshot("before_host_session")
        manager.host_session()
        _snapshot("after_host_session")
        _check(manager._has_live_peer() and multiplayer.is_server(), "actual host transport")
    stage = "post_load_frames"
    for frame in range(20):
        _snapshot("before_post_load_physics_" + str(frame))
        await get_tree().physics_frame
        await get_tree().process_frame
    _check(true, "twenty post-load physics frames completed")
    if role == "host":
        _check(Ref.world.instance_radius == loaded_radius and Ref.world.buffer_instance_radius == loaded_buffer_radius, "hosting preserves initialized local radius and buffer")
    _mark("observed", {"checks": checks, "failures": failures})
    stage = "shutdown"
    var manager = _manager()
    if role == "host" and manager != null:
        await manager._shutdown_host_session(false, "startup control finished")
    if not await _wait(func(): return Ref.world.is_all_loaded(), "finish loading before quit"):
        return
    await Ref.main.quit_game(true, true)
    var keyboard = get_node_or_null("/root/Main/UI/OnscreenKeyboard")
    if keyboard != null:
        var helper = keyboard.get("KeyListHandler")
        if is_instance_valid(helper) and helper is Node and not helper.is_inside_tree() and helper.get_script().resource_path == "res://addons/onscreenkeyboard/keylist.gd":
            helper.free()
            keyboard.set("KeyListHandler", null)
    _mark("complete", {"checks": checks, "failures": failures})
    print("WORLD_STARTUP_RESULT ", role, " ", checks, " checks ", failures, " failures")
    get_tree().quit(1 if failures else 0)
