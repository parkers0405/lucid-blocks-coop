extends Node

var role: String
var scenario: String
var port: int
var checks: int = 0
var failures: int = 0
var seeded: bool = false
var stage: String = "startup"
var background_finished: bool = false
var background_ok: bool = false
var next_diagnostic: int = 0
var sample: Dictionary = {}
var sample_prev: Vector3 = Vector3.ZERO
var sample_prev_us: int = 0

func _sample_begin(label: String) -> void:
    sample = {"label": label, "frames": 0, "moved": 0, "disabled": 0, "locked": 0, "handoff_locked": 0, "over50ms": 0, "max_us": 0, "start_ms": Time.get_ticks_msec()}
    sample_prev = Ref.player.global_position
    sample_prev_us = Time.get_ticks_usec()

func _sample_end() -> void:
    sample["ms"] = Time.get_ticks_msec() - int(sample["start_ms"])
    print("FRICTION ", role, " ", JSON.stringify(sample))
    sample = {}

func _physics_process(_delta: float) -> void:
    if sample.is_empty() or not is_instance_valid(Ref.player) or not is_instance_valid(Ref.coop_manager):
        return
    var now_us: int = Time.get_ticks_usec()
    var gap: int = now_us - sample_prev_us
    sample_prev_us = now_us
    var manager = Ref.coop_manager
    var position: Vector3 = Ref.player.global_position
    var step: float = Vector2(position.x - sample_prev.x, position.z - sample_prev.z).length()
    sample_prev = position
    sample["frames"] += 1
    sample["max_us"] = maxi(int(sample["max_us"]), gap)
    if gap > 50000:
        sample["over50ms"] += 1
    if step > 0.001:
        sample["moved"] += 1
    if Ref.player.disabled:
        sample["disabled"] += 1
    if manager._is_client_gameplay_locked():
        sample["locked"] += 1
        if manager.lease_frozen or manager.lease_preparing:
            sample["handoff_locked"] += 1

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
        if Time.get_ticks_msec() > next_diagnostic and is_instance_valid(Ref.coop_manager) and is_instance_valid(Ref.player) and is_instance_valid(Ref.world):
            next_diagnostic = Time.get_ticks_msec() + 3000
            var manager = Ref.coop_manager
            print("LEASE_DIAG ", role, " probe=", manager.lease_probe_busy, " busy=", manager.lease_busy, " frozen=", manager.lease_frozen, " phase=", manager.lease_phase, " epoch=", manager.chunk_authority.lease_epoch, " guest_instance=", manager.lease_guest_instance, " chunks=", manager.lease_guest_chunks.size(), " profile_busy=", manager.host_profile_busy, " region_busy=", manager.region_commit_busy, " status=", manager.status_message, " ready=", manager.guest_persistent_ready, " receiving=", manager.receiving_host_world, " restore=", manager.client_restore_in_progress, " reconnect=", manager.reconnect_pending, " player_disabled=", Ref.player.disabled, " dimension=", Ref.world.current_dimension, " wait=", label)
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
    var edits = JSON.parse_string(FileAccess.get_file_as_string(scenario.path_join("guest_edits.json")))
    var region_namespace: String = SaveFile.DIMENSION_MAP[int(edits["dimension"])]
    var stored: Dictionary = await manager._store_job(manager.region_checkpoint, "read_regions", [manager._get_checkpoint_chunks_directory(), region_namespace, manager._checkpoint_block_ids()], {})
    var position := Vector3i(edits["x"], edits["y"], edits["z"])
    var chunk: Vector3i = manager._lease_chunk(Vector3(position))
    var region: Dictionary = stored.get("regions", {}).get(manager.RegionCheckpoint.region_coordinate(chunk), {})
    var cells: PackedInt32Array = region.get("chunk_block", {}).get(chunk, PackedInt32Array())
    var offset: Vector3i = position - chunk
    check(stored.get("ok", false) and cells.size() == 4096 and cells[offset.x + 16 * offset.z + 256 * offset.y] == int(edits["block"]), "host canonical disk retains latest guest edit")
    check(not Ref.world.is_position_loaded(Vector3(position)), "guest checkpoint retains independent host loading bubble")
    _mark("accepted")
    if not await _wait(func(): return FileAccess.file_exists(scenario.path_join("guest_dimension.json")), "guest independently changed dimension", 120.0):
        return false
    if not await _wait(func(): return not manager.admitted_player_keys.is_empty() and manager.peer_states.get(int(manager.admitted_player_keys.keys()[0]), {}).get("active", false) and manager.peer_states.get(int(manager.admitted_player_keys.keys()[0]), {}).get("dimension") == 2, "host received guest dimension state", 30.0):
        return false
    check(int(Ref.world.current_dimension) == 1, "guest dimension travel leaves host in original world")
    manager._teleport_to_peer(int(manager.admitted_player_keys.keys()[0]))
    if not await _wait(func(): return int(Ref.world.current_dimension) == 2 and _world_ready() and manager.pending_peer_teleport == 0 and not manager.lease_busy and not manager.lease_preparing and not manager.admitted_player_keys.is_empty(), "host teleport follows guest across dimensions", 90.0):
        return false
    var guest_state: Dictionary = manager.peer_states.get(int(manager.admitted_player_keys.keys()[0]), {})
    check(Ref.player.global_position.distance_to(Vector3(guest_state.get("position", Vector3.INF))) < 12.0, "cross-dimension teleport finishes near selected player")
    _mark("followed")
    if not await _wait(func(): return manager.admitted_player_keys.is_empty() and FileAccess.file_exists(scenario.path_join("guest_complete.json")), "guest disconnected after recovery", 150.0):
        return false
    check(await manager._shutdown_host_session(false, "local fixture finished"), "host shutdown waits for ownership recovery and commits world")
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
    var native_methods: Array = []
    for method in ClassDB.class_get_method_list("World"):
        if "chunk" in method["name"] or "region" in method["name"] or "save" in method["name"]:
            native_methods.append(method["name"])
    var native_data: Dictionary = {}
    Ref.world.register_loaded_chunks()
    var native_prefix: String = SaveFile.DIMENSION_MAP[int(Ref.world.current_dimension)] + "_"
    Ref.world.save_data(native_data, native_prefix)
    print("NATIVE_WORLD_METHODS ", native_methods)
    print("NATIVE_WORLD_SAVE keys=", native_data.keys(), " prefix=", native_prefix)
    for key in native_data:
        if native_data[key] is Dictionary:
            print("NATIVE_WORLD_SAVE_ROOT ", key, " keys=", native_data[key].keys())
    var before_move: Vector3 = Ref.player.global_position
    Ref.player.process_mode = Node.PROCESS_MODE_ALWAYS
    MouseHandler.window_focused = true
    MouseHandler.capture()
    Input.action_press("up")
    _sample_begin("free_walk")
    for frame in range(60):
        await get_tree().physics_frame
    _sample_end()
    manager.begin_chest_inventory_lock(false)
    _sample_begin("pickup_lock_walk")
    for frame in range(60):
        await get_tree().physics_frame
    _sample_end()
    print("PLAYER_MOVEMENT_DIAG before=", before_move, " after=", Ref.player.global_position, " movement_enabled=", Ref.player.movement_enabled, " mouse_focus=", MouseHandler.window_focused, " captured=", MouseHandler.captured, " disabled=", Ref.player.disabled, " process_mode=", Ref.player.process_mode, " paused=", get_tree().paused, " loaded=", Ref.world.is_position_loaded(Ref.player.global_position), " input=", Input.get_action_strength("up"), " velocity=", Ref.player.movement_velocity)
    Input.action_release("up")
    check(not Ref.player.disabled and Vector2(Ref.player.global_position.x - before_move.x, Ref.player.global_position.z - before_move.z).length() > 0.01, "real player moves during pickup inventory lock")
    manager._release_chest_inventory_lock()
    var input_frames: int = 0
    var disabled_frames: int = 0
    var max_gap_us: int = 0
    var previous_us: int = Time.get_ticks_usec()
    var sampling_until: int = Time.get_ticks_msec() + 6000
    while Time.get_ticks_msec() < sampling_until:
        await get_tree().process_frame
        var current_us: int = Time.get_ticks_usec()
        max_gap_us = maxi(max_gap_us, current_us - previous_us)
        previous_us = current_us
        input_frames += 1
        if Ref.player.disabled and not manager.lease_busy and not manager.lease_preparing and not manager.lease_frozen:
            disabled_frames += 1
    print("PLAYER_EXPERIENCE_INPUT frames=", input_frames, " disabled_without_handoff=", disabled_frames, " max_frame_us=", max_gap_us)
    if manager.has_method("_checkpoint_terrain_in_background"):
        Ref.player.global_position += Vector3(1024, 0, 0)
        Input.action_press("up")
        _sample_begin("handoff_walk")
        var handoff_ok: bool = await _wait(func(): return _world_ready() and not manager.lease_busy and not manager.lease_preparing and not manager.lease_frozen and not manager.terrain_sync_busy and manager.chunk_authority.leased_owner(manager._lease_chunk(Ref.player.global_position), manager.get_active_dimension_instance_key()) == 2, "independent guest bubble", 45.0)
        Input.action_release("up")
        _sample_end()
        if not handoff_ok:
            _checkpoint_status(manager, "independent_deadline")
            print("PLAYER_EXPERIENCE_INDEPENDENT position=", Ref.player.global_position, " world_mode=", Ref.world.process_mode, " tree_paused=", get_tree().paused, " owner=", manager.chunk_authority.leased_owner(manager._lease_chunk(Ref.player.global_position), manager.get_active_dimension_instance_key()), " guest_chunks=", manager._local_loaded_lease_chunks().size(), " peers=", manager.peer_states)
            return false
        var solids: Array = []
        for block in Ref.world.get_block_types():
            if block.id > 1 and not block.foliage and not block.no_collision_block and block.living_block_path.is_empty():
                solids.append(block.id)
                if solids.size() == 2:
                    break
        var position := Vector3i(Ref.player.global_position.floor()) + Vector3i(3, 0, 0)
        Ref.world.place_block_at(position, ItemMap.map(solids[0]), false, false)
        print("EDIT_FIRST expected=", solids[0], " actual=", Ref.world.get_block_type_at(position).id)
        _background_checkpoint(manager)
        Ref.world.break_block_at(position, false, false)
        Ref.world.place_block_at(position, ItemMap.map(solids[1]), false, false)
        print("EDIT_SECOND expected=", solids[1], " actual=", Ref.world.get_block_type_at(position).id)
        if not await _wait(func(): return background_finished, "old snapshot acknowledged", 30.0):
            return false
        print("EDIT_ACK ok=", background_ok, " actual=", Ref.world.get_block_type_at(position).id, " expected=", solids[1])
        check(background_ok and Ref.world.get_block_type_at(position).id == solids[1], "newer live edit survives old acknowledged snapshot")
        background_finished = false
        _background_checkpoint(manager)
        if not await _wait(func(): return background_finished, "latest snapshot persisted", 30.0):
            return false
        check(background_ok and not Ref.player.disabled, "latest independent edit saved without input lock")
        _mark("edits", {"dimension": int(Ref.world.current_dimension), "x": position.x, "y": position.y, "z": position.z, "block": solids[1]})
    _mark("ready", {"key_hash": manager._get_local_player_key().sha256_text()})
    if not await _wait(func(): return FileAccess.file_exists(scenario.path_join("host_accepted.json")), "host identity accepted"):
        return false
    _checkpoint_status(manager, "before")
    var checkpoint_ok: bool = await manager._await_local_world_checkpoint()
    _checkpoint_status(manager, "after")
    check(checkpoint_ok, "guest final durable checkpoint acknowledged")
    var approved = JSON.parse_string(FileAccess.get_file_as_string(scenario.path_join("guest_edits.json")))
    var approved_position := Vector3i(approved["x"], approved["y"], approved["z"])
    Ref.world.break_block_at(approved_position, false, false)
    manager._begin_reconnect_flow("local connection recovery fixture")
    check(manager.reconnect_pending and Ref.player.disabled, "connection recovery blocks independent offline progress")
    if not await _wait(func(): return _world_ready() and manager.guest_persistent_ready and not manager.reconnect_pending and not manager.client_restore_in_progress and not manager.receiving_host_world, "guest reconnect restores approved world", 90.0):
        return false
    check(Ref.world.get_block_type_at(approved_position).id == int(approved["block"]) and not Ref.player.disabled, "reconnect restores host-approved terrain and releases input")
    if not await _wait(func(): return not manager.lease_busy and not manager.lease_frozen and not manager.lease_preparing, "reconnected ownership settled", 30.0):
        return false
    manager._open_dimension_instance_async(2)
    if not await _wait(func(): return int(Ref.world.current_dimension) == 2 and _world_ready() and manager.guest_persistent_ready and not manager.client_restore_in_progress and not manager.receiving_host_world, "independent guest dimension travel", 90.0):
        return false
    check(not Ref.player.disabled, "independent dimension travel restores guest input")
    _mark("dimension")
    if not await _wait(func(): return FileAccess.file_exists(scenario.path_join("host_followed.json")), "host followed cross-dimension teleport", 90.0):
        return false
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

func _background_checkpoint(manager: Node) -> void:
    background_ok = await manager._checkpoint_terrain_in_background()
    background_finished = true
