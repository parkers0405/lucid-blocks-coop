extends Node

var role: String
var scenario: String
var port: int
var checks: int = 0
var failures: int = 0
var seeded: bool = false
var stage: String = "startup"

func _enter_tree() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var args := OS.get_cmdline_user_args()
    if args.size() != 3:
        push_error("LOCAL_COOP invalid arguments")
        return
    role = args[0]
    scenario = args[1]
    port = int(args[2])
    get_tree().node_added.connect(_observe)
    _scan(get_tree().root)

func _ready() -> void:
    call_deferred("_run")

func _scan(node: Node) -> void:
    _observe(node)
    for child in node.get_children():
        _scan(child)

func _observe(node: Node) -> void:
    # Headless has no post-draw signal; icon baking is unrelated to gameplay.
    if node.get_script() != null and node.get_script().resource_path == "res://main/items/icon_generator/icon_generator.gd":
        node.skip = true
    if node.get_script() != null and node.get_script().resource_path == "res://main/save_file/save_file_manager.gd":
        if node.is_node_ready():
            _seed(node)
        elif not node.ready.is_connected(_seed.bind(node)):
            node.ready.connect(_seed.bind(node), CONNECT_ONE_SHOT)

func _seed(manager: Node) -> void:
    manager.device_file.set_data("save_version", ProjectSettings.get_setting("application/config/version"))
    manager.device_file.set_data("shaders_baked", true)
    manager.device_file.set_data("tutorial", false)
    manager.settings_file.set_data("render_distance", 16.0)
    seeded = true
    print("LOCAL_COOP_SEEDED ", role)

func _mark(name_value: String, value: Dictionary = {}) -> void:
    var target: String = scenario.path_join(role + "_" + name_value + ".json")
    var file := FileAccess.open(target + ".tmp", FileAccess.WRITE)
    file.store_string(JSON.stringify(value))
    file.flush()
    file.close()
    if DirAccess.rename_absolute(target + ".tmp", target) != OK:
        push_error("LOCAL_COOP marker publication failed")
        return
    print("LOCAL_COOP_STAGE ", role, " ", name_value)

func _wait(predicate: Callable, label: String, seconds: float = 60.0) -> bool:
    stage = label
    var deadline: int = Time.get_ticks_msec() + int(seconds * 1000)
    while not predicate.call():
        if Time.get_ticks_msec() >= deadline:
            check(false, "deadline " + label)
            return false
        await get_tree().create_timer(0.05, true, false, true).timeout
    return true

func check(ok: bool, label: String) -> void:
    checks += 1
    print("LOCAL_COOP_CHECK ", role, " ", "PASS " if ok else "FAIL ", label)
    if not ok:
        failures += 1
        _mark("failed", {"stage": stage, "label": label})

func _world_ready() -> bool:
    return Ref.world.load_enabled and Ref.world.is_all_loaded() and not Ref.player.disabled

func _configure(manager: Node) -> void:
    for name_value in ["address_input", "main_menu_coop_address_input", "pause_menu_coop_address_input"]:
        var widget = manager.get(name_value)
        if is_instance_valid(widget):
            widget.text = "127.0.0.1"
    for name_value in ["port_input", "main_menu_coop_port_input", "pause_menu_coop_port_input"]:
        var widget = manager.get(name_value)
        if is_instance_valid(widget):
            widget.value = port
            widget.get_line_edit().text = str(port)

func _run() -> void:
    if not FileAccess.file_exists(scenario.path_join(".local-coop-scenario")):
        push_error("LOCAL_COOP disposable marker missing")
        get_tree().quit(1)
        return
    if not await _wait(func(): return seeded and Ref.main != null and Ref.main.loaded and Ref.coop_manager != null, "menu startup"):
        return
    var manager = Ref.coop_manager
    _configure(manager)
    var succeeded: bool
    if role == "host":
        succeeded = await _run_host(manager)
    else:
        succeeded = await _run_guest(manager)
    if not succeeded:
        return
    stage = "shutdown"
    if not await _wait(func(): return Ref.world.is_all_loaded(), "finish native loading"):
        return
    await Ref.main.quit_game(true, true)
    var keyboard = get_node_or_null("/root/Main/UI/OnscreenKeyboard")
    if keyboard != null:
        var helper = keyboard.get("KeyListHandler")
        if is_instance_valid(helper) and helper is Node and not helper.is_inside_tree() and helper.get_script().resource_path == "res://addons/onscreenkeyboard/keylist.gd":
            helper.free()
            keyboard.set("KeyListHandler", null)
    _mark("complete", {"checks": checks, "failures": failures})
    print("LOCAL_COOP_RESULT ", role, " ", checks, " checks ", failures, " failures")
    get_tree().quit(1 if failures else 0)

func _run_host(manager: Node) -> bool:
    var files = Ref.save_file_manager
    files.initialize_file()
    var register = files.loaded_file_register
    var settings := {"dimension": 1, "divine": true, "progression_disabled": true, "world_seed": 12345, "find_spawn": false, "reset_world": false, "title": "Disposable local co-op smoke"}
    for entry in settings:
        register.set_data(entry, settings[entry], true)
    files.initialize_save_file_directory(register.get_data("uuid"), false)
    files.load_file(register)
    stage = "enter host game"
    await Ref.main.enter_game()
    if not await _wait(_world_ready, "host loaded"):
        return false
    _configure(manager)
    manager.host_session()
    check(manager._has_live_peer() and multiplayer.is_server(), "actual LAN host transport")
    _mark("ready")
    if not await _wait(func(): return FileAccess.file_exists(scenario.path_join("guest_ready.json")), "guest ready", 90.0):
        return false
    check(manager.admitted_player_keys.size() == 1 and multiplayer.get_peers().size() == 1, "one admitted real guest")
    var guest_data = JSON.parse_string(FileAccess.get_file_as_string(scenario.path_join("guest_ready.json")))
    check(str(manager.admitted_player_keys.values()[0]).sha256_text() == guest_data["key_hash"], "transport-bound guest identity agrees")
    _mark("accepted")
    if not await _wait(func(): return manager.admitted_player_keys.is_empty(), "guest disconnected"):
        return false
    await manager._shutdown_host_session(false, "local fixture finished")
    return true

func _run_guest(manager: Node) -> bool:
    check(not Ref.world.load_enabled, "guest starts at menu without preloaded world")
    if not await _wait(func(): return FileAccess.file_exists(scenario.path_join("host_ready.json")), "host ready", 90.0):
        return false
    _configure(manager)
    manager.join_session()
    if not await _wait(func(): return _world_ready() and manager.guest_persistent_ready and manager.client_world_sync_ready and not manager.receiving_host_world and not manager.client_restore_in_progress, "production guest snapshot/profile load", 90.0):
        print("LOCAL_COOP_STATUS ", manager.status_message)
        return false
    check(manager._has_live_peer() and not multiplayer.is_server(), "actual LAN guest transport")
    check(Ref.world.current_dimension == 1, "host creative world installed from menu")
    if not await _wait(func(): return manager.chunk_authority.lease_epoch > 0 and not manager.lease_busy and not manager.lease_frozen and not manager.lease_preparing and _world_ready(), "initial runtime lease installed", 30.0):
        _checkpoint_status(manager, "lease_deadline")
        return false
    check(true, "initial runtime lease installed before guest action")
    _mark("ready", {"key_hash": manager._get_local_player_key().sha256_text()})
    if not await _wait(func(): return FileAccess.file_exists(scenario.path_join("host_accepted.json")), "host identity accepted"):
        return false
    _checkpoint_status(manager, "before")
    var checkpoint_ok: bool = await manager._await_local_world_checkpoint()
    _checkpoint_status(manager, "after")
    check(checkpoint_ok, "guest final durable checkpoint acknowledged")
    manager.disconnect_session(false)
    return true

func _checkpoint_status(manager: Node, event: String) -> void:
    print("LOCAL_COOP_CHECKPOINT ", JSON.stringify({
        "event": event, "revision": manager.profile_revision,
        "profile_pending": manager.profile_commit_pending,
        "checkpoint_busy": manager.guest_checkpoint_busy,
        "canonical_busy": manager.canonical_apply_busy,
        "canonical_pending": manager.pending_canonical_patches.size(),
        "lease_busy": manager.lease_busy, "lease_frozen": manager.lease_frozen, "lease_preparing": manager.lease_preparing,
        "lease_allowed": manager.lease_checkpoint_allowed,
        "lease_phase": manager.lease_phase, "lease_epoch": manager.chunk_authority.lease_epoch,
        "reconnect": manager.reconnect_pending, "restore": manager.client_restore_in_progress,
                "player_disabled": Ref.player.disabled, "load_enabled": Ref.world.load_enabled,
        "all_loaded": Ref.world.is_all_loaded(), "lease_was_disabled": manager.lease_was_disabled,
        "status": manager.status_message,
    }))
