extends Node

# Test-only friction probe: bots, per-frame telemetry and disk fault injection. Never part of the release PCK.

class FaultQueue extends "res://coop_mod/save_queue.gd":
    var disk: String = "fast"
    var rng := RandomNumberGenerator.new()
    var mutex := Mutex.new()
    var records: Array = []
    var failed: int = 0

    func _execute(job) -> void:
        var method: String = job.operation.get_method()
        var delay: int = 0
        if disk != "fast":
            mutex.lock()
            delay = 250
            if rng.randf() < 0.05:
                delay = 1500
            var fail: bool = disk == "failing" and not method.begins_with("read") and rng.randi() % 15 == 0
            mutex.unlock()
            OS.delay_msec(delay)
            if fail:
                mutex.lock()
                failed += 1
                records.append([method, delay, "failed"])
                mutex.unlock()
                job.result = null
                return
        mutex.lock()
        records.append([method, delay, "ok"])
        mutex.unlock()
        super(job)

class FakeChestBlock extends Node3D:
    var broken: bool = false

var role: String
var scenario: String
var port: int
var config: Dictionary = {}
var checks: int = 0
var failures: int = 0
var seeded: bool = false
var stage: String = "startup"
var next_diagnostic: int = 0
var bot_active: bool = false
var tele: PackedStringArray = []
var tele_file: FileAccess
var prev_pos: Vector3 = Vector3.ZERO
var prev_us: int = 0
var prev_bb: bool = false
var prev_progress: float = 0.0
var fault_queue
var item_total_prev: int = -1
var pending_breaks: Array = []
var pickup_ms: Array = []
var mined: int = 0
var spawned: Dictionary = {}
var kill_seen: bool = false
var peer_gone_seen: bool = false
var items0: int = 0
const LOCK_FLAGS := ["chest_lock_active", "chest_movement_locked", "lease_preparing", "lease_frozen", "lease_busy", "guest_checkpoint_busy", "reconnect_pending", "client_restore_in_progress", "receiving_host_world", "pickup_inventory_lock", "durable_pickup_busy", "terrain_sync_busy"]

func _enter_tree() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var args := OS.get_cmdline_user_args()
    if args.size() != 3:
        push_error("LOCAL_COOP invalid arguments")
        return
    role = args[0]
    scenario = args[1]
    port = int(args[2])
    config = JSON.parse_string(FileAccess.get_file_as_string(scenario.path_join("config.json")))
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

func _item_total() -> int:
    var total: int = 0
    for inventory in [Ref.player_inventory, Ref.player_hotbar, Ref.player_equipment]:
        if is_instance_valid(inventory):
            for item in inventory.items:
                if item != null:
                    total += item.count
    return total

# Per item id counts across inventories (the conservation oracle compares ids, not just totals).
func _item_tally() -> Dictionary:
    var tally: Dictionary = {}
    for inventory in [Ref.player_inventory, Ref.player_hotbar, Ref.player_equipment]:
        if is_instance_valid(inventory):
            for item in inventory.items:
                if item != null:
                    tally[item.id] = int(tally.get(item.id, 0)) + item.count
    return tally

func _drops_tally() -> Dictionary:
    var tally: Dictionary = {}
    for node in get_tree().root.get_children():
        if node.get_script() != null and node.get_script().resource_path == "res://main/items/dropped_item/dropped_item.gd" and node.item != null:
            tally[node.item.id] = int(tally.get(node.item.id, 0)) + node.item.count
    return tally

func _drops_left() -> int:
    var total: int = 0
    for node in get_tree().root.get_children():
        if node.get_script() != null and node.get_script().resource_path == "res://main/items/dropped_item/dropped_item.gd" and node.item != null:
            total += node.item.count
    return total

func _physics_process(_delta: float) -> void:
    if not is_instance_valid(Ref.player) or not is_instance_valid(Ref.coop_manager) or not is_instance_valid(Ref.world) or not Ref.world.load_enabled:
        return
    var now_us: int = Time.get_ticks_usec()
    var gap: int = now_us - prev_us
    prev_us = now_us
    var manager = Ref.coop_manager
    var position: Vector3 = Ref.player.global_position
    var step: float = (position - prev_pos).length()
    prev_pos = position
    var flags: PackedStringArray = []
    for name_value in LOCK_FLAGS:
        if manager.get(name_value):
            flags.append(name_value)
    var bb = Ref.player.get_node_or_null("%BreakBlocks")
    var breaking: bool = bb != null and bb.breaking
    var progress: float = bb.progress if bb != null else 0.0
    var locked: bool = manager._is_client_gameplay_locked()
    var reset: int = 1 if (prev_bb and not breaking and prev_progress > 0.0 and bot_active and Input.is_action_pressed("attack") and locked) else 0
    prev_bb = breaking
    prev_progress = progress
    if role == "host" and not kill_seen and FileAccess.file_exists(scenario.path_join("guest_killpoint.json")):
        kill_seen = true
        _event("kill_seen")
    if kill_seen and not peer_gone_seen and manager.admitted_player_keys.is_empty():
        peer_gone_seen = true
        _event("peer_gone")
    var total: int = _item_total()
    while not pending_breaks.is_empty() and Time.get_ticks_msec() - int(pending_breaks[0]) > 3000:
        pending_breaks.pop_front()
    if item_total_prev >= 0 and total > item_total_prev and not pending_breaks.is_empty():
        pickup_ms.append(Time.get_ticks_msec() - int(pending_breaks.pop_front()))
    if total != item_total_prev:
        _event("items", {"total": total, "tally": _item_tally()})
    item_total_prev = total
    var spawner = Ref.entity_spawner
    var row := {"t": Time.get_ticks_msec(), "dt": gap, "in": 1 if bot_active else 0, "mi": 1 if (Input.is_action_pressed("up") or Input.is_action_pressed("down")) else 0, "mv": snappedf(step, 0.001),
        "dis": 1 if Ref.player.disabled else 0, "lk": 1 if locked else 0, "f": ",".join(flags),
        "atk": 1 if Input.is_action_pressed("attack") else 0, "brk": 1 if breaking else 0, "prog": snappedf(progress, 0.01), "rst": reset,
        "sim": 1 if Ref.world.simulate_enabled else 0, "ent": 1 if (is_instance_valid(spawner) and spawner.process_mode != Node.PROCESS_MODE_DISABLED) else 0,
        "ld": 0 if Ref.world.is_all_loaded() else 1, "q": fault_queue.pending.size() if fault_queue != null else -1}
    tele.append(JSON.stringify(row))
    if tele.size() >= 240:
        _flush_tele()

func _flush_tele() -> void:
    if tele_file == null:
        tele_file = FileAccess.open(scenario.path_join(role + "_telemetry.jsonl"), FileAccess.WRITE)
    if tele_file != null and not tele.is_empty():
        tele_file.store_string("\n".join(tele) + "\n")
        tele_file.flush()
    tele.clear()

func _event(name_value: String, extra: Dictionary = {}) -> void:
    extra["ev"] = name_value
    extra["t"] = Time.get_ticks_msec()
    tele.append(JSON.stringify(extra))

func _aim(yaw: float, pitch: float) -> void:
    Ref.player.get_node("%RotationPivot").rotation.y = yaw
    Ref.player._set_camera_pitch(pitch)

func _bot_on() -> void:
    Ref.player.process_mode = Node.PROCESS_MODE_ALWAYS
    MouseHandler.window_focused = true
    MouseHandler.capture()
    bot_active = true
    items0 = _item_total()

func _bot_off() -> void:
    for action in ["up", "down", "left", "right", "sprint", "attack", "interact", "jump"]:
        Input.action_release(action)
    bot_active = false

func _solid_block_ids() -> Array:
    var solids: Array = []
    for block in Ref.world.get_block_types():
        if block.id > 1 and not block.foliage and not block.no_collision_block and block.living_block_path.is_empty():
            solids.append(block.id)
    return solids

func _spawn_drop(block_id: int, at: Vector3) -> void:
    var state := ItemState.new()
    state.initialize(ItemMap.map(block_id))
    state.count = 1
    var drop = load("res://main/items/dropped_item/dropped_item.tscn").instantiate()
    drop.position = at
    # Native stack merging is racy (solo gained 29..31 of 30), so the conservation oracle spawns non-merging drops.
    drop.can_merge = false
    get_tree().get_root().add_child(drop)
    drop.initialize(state)
    spawned[block_id] = int(spawned.get(block_id, 0)) + 1

func _wait_marker(from_role: String, name_value: String, seconds: float = 120.0) -> bool:
    return await _wait(func(): return FileAccess.file_exists(scenario.path_join(from_role + "_" + name_value + ".json")), "marker " + from_role + "_" + name_value, seconds)

# Scenarios: bot input only; the co-op code runs unmodified.
func _scn_mine_tunnel(_manager: Node) -> bool:
    # The test world is a thin slab (about 4 mineable blocks), so the bot digs down with real attack input and steps two cells aside when the floor is reached.
    _bot_on()
    var count: int = int(config.get("blocks", 40))
    var started: int = Time.get_ticks_msec()
    var bb = Ref.player.get_node("%BreakBlocks")
    var misses: int = 0
    if role == "guest":
        # Separate columns so the two players do not mine the same blocks.
        Ref.player.global_position += Vector3(0.0, 0.5, 8.0)
        await get_tree().create_timer(0.5, true, false, true).timeout
    while mined < count and misses < 6:
        _aim(0.0, -deg_to_rad(89.0))
        Input.action_press("attack")
        var broke: bool = false
        var deadline: int = Time.get_ticks_msec() + 5000
        var target := Vector3i.ZERO
        var seen: bool = false
        while Time.get_ticks_msec() < deadline:
            await get_tree().physics_frame
            if bb.breaking:
                target = bb.active_position
                seen = true
            elif seen:
                if Ref.world.get_block_type_at(target).id <= 1:
                    broke = true
                    break
                seen = false
        Input.action_release("attack")
        if broke:
            mined += 1
            misses = 0
            pending_breaks.append(Time.get_ticks_msec())
            await get_tree().create_timer(0.4, true, false, true).timeout
        else:
            misses += 1
            Ref.player.global_position += Vector3(2.0, 0.5, 0.0)
            await get_tree().create_timer(0.6, true, false, true).timeout
    _event("scenario_done", {"name": "mine_tunnel", "mined": mined, "elapsed_ms": Time.get_ticks_msec() - started})
    check(mined >= count / 2, "mined %d of %d blocks" % [mined, count])
    _bot_off()
    return true

func _scn_shared_loot(_manager: Node) -> bool:
    _bot_on()
    var started: int = Time.get_ticks_msec()
    if role != "guest":
        var pile: Vector3 = Ref.player.global_position
        var block_id: int = _solid_block_ids()[0]
        for index in range(30):
            _spawn_drop(block_id, pile + Vector3(0.1 * (index % 5), 1.0, 0.1 * (index / 5)))
        _mark("pile", {"x": pile.x, "y": pile.y, "z": pile.z, "block": block_id})
    else:
        if not await _wait_marker("host", "pile"):
            return false
    await get_tree().create_timer(15.0, true, false, true).timeout
    _event("scenario_done", {"name": "shared_loot", "elapsed_ms": Time.get_ticks_msec() - started, "items": _item_total()})
    _bot_off()
    return true

func _scn_handoff_motion(_manager: Node) -> bool:
    _bot_on()
    var origin: Vector3 = Ref.player.global_position
    var started: int = Time.get_ticks_msec()
    if role != "host":
        for trip in range(int(config.get("trips", 2))):
            for yaw in [-PI / 2.0, PI / 2.0]:
                _aim(yaw, 0.0)
                Input.action_press("up")
                Input.action_press("sprint")
                var deadline: int = Time.get_ticks_msec() + 90000
                while Time.get_ticks_msec() < deadline:
                    await get_tree().physics_frame
                    var d: float = Ref.player.global_position.x - origin.x
                    if (yaw < 0.0 and d > 300.0) or (yaw > 0.0 and d < 4.0):
                        break
                Input.action_release("up")
                Input.action_release("sprint")
                _event("leg_done", {"x": Ref.player.global_position.x - origin.x})
        _mark("motion_done")
    elif not await _wait_marker("guest", "motion_done", 400.0):
        return false
    _event("scenario_done", {"name": "handoff_motion", "elapsed_ms": Time.get_ticks_msec() - started})
    _bot_off()
    return true

# G7 kill tests: the runner hard-kills the guest when it publishes guest_killpoint, relaunches it with guest_recover.flag, and the
# recovered guest reports its inventory so conservation (host + guest + drops left = spawned) can be checked.
func _publish_kill_and_hold() -> void:
    _mark("killpoint", {"point": str(config.get("kill_guest_at", "")), "t": Time.get_ticks_msec()})
    await get_tree().create_timer(300.0, true, false, true).timeout

func _spawn_pile(count: int) -> void:
    var pile: Vector3 = Ref.player.global_position
    var block_id: int = _solid_block_ids()[0]
    for index in range(count):
        _spawn_drop(block_id, pile + Vector3(0.1 * (index % 5), 1.0, 0.1 * (index / 5)))
    _mark("pile", {"x": pile.x, "y": pile.y, "z": pile.z, "block": block_id, "count": count})

func _scn_kill_pickup(manager: Node) -> bool:
    return await _scn_kill(manager)

func _scn_kill_chest(manager: Node) -> bool:
    return await _scn_kill(manager)

func _scn_kill_handoff(manager: Node) -> bool:
    return await _scn_kill(manager)

func _scn_kill(manager: Node) -> bool:
    var point: String = str(config.get("kill_guest_at", "pickup"))
    _bot_on()
    if role != "guest":
        if point != "chest":
            _spawn_pile(30)
        else:
            var accesses: Dictionary = Ref.save_file_manager.loaded_file.get_data("coop/chest_access", {}, true).duplicate(true)
            accesses[manager._chest_access_key(manager.get_active_dimension_instance_key(), Vector3i(Ref.player.global_position))] = true
            Ref.save_file_manager.loaded_file.set_data("coop/chest_access", accesses, true)
            _mark("chest", {"x": Ref.player.global_position.x, "y": Ref.player.global_position.y, "z": Ref.player.global_position.z})
        if not await _wait_marker("guest", "recovered", 300.0):
            return false
        await get_tree().create_timer(10.0, true, false, true).timeout
        _event("scenario_done", {"name": "kill_" + point})
        _bot_off()
        return true
    if point != "chest" and not await _wait_marker("host", "pile"):
        return false
    if point == "pickup":
        if not await _wait(func(): return not manager.pickup_pending.is_empty(), "pickup pending"):
            return false
        await _publish_kill_and_hold()
    elif point == "chest":
        if not await _wait_marker("host", "chest"):
            return false
        # Grant 5 items locally; the chest request carries this state to the host, so the oracle is exactly 5 across inventory + chest.
        var granted := ItemState.new()
        granted.initialize(ItemMap.map(_solid_block_ids()[0]))
        granted.count = 5
        Ref.player_hotbar.set_item(0, granted)
        var cube := FakeChestBlock.new()
        add_child(cube)
        var spot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scenario.path_join("host_chest.json")))
        cube.global_position = Vector3(spot["x"], spot["y"], spot["z"])
        manager.open_personal_chest(cube)
        if not await _wait(func(): return is_instance_valid(manager.chest_panel) and manager.chest_panel.session != "" and not manager.chest_panel.busy, "chest session", 20.0):
            return false
        manager.chest_panel._select_slot(0)
        manager.chest_panel._request_transfer("Hotbar", 0, true)
        # With the slow disk the transfer job outlasts the runner's 100 ms kill poll; the request is in flight either way.
        await get_tree().physics_frame
        await get_tree().physics_frame
        check(not manager.chest_pending_token.is_empty(), "chest transfer in flight at kill point")
        await _publish_kill_and_hold()
    elif point == "install0":
        var origin: Vector3 = Ref.player.global_position
        _aim(-PI / 2.0, 0.0)
        Input.action_press("up")
        Input.action_press("sprint")
        # Guest is frozen, its checkpoint is acknowledged and the host is installing the new owners (phase install_0 .. resume).
        var deadline: int = Time.get_ticks_msec() + 150000
        while not (manager.lease_frozen and not manager.lease_checkpoint_allowed) and Time.get_ticks_msec() < deadline:
            await get_tree().physics_frame
        if not (manager.lease_frozen and not manager.lease_checkpoint_allowed):
            check(false, "guest never reached the install phase of a handoff")
            return false
        await _publish_kill_and_hold()
    else:
        check(false, "unknown kill point " + point)
    return false

func _open_chest_and_read(manager: Node) -> int:
    var cube := FakeChestBlock.new()
    add_child(cube)
    var spot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scenario.path_join("host_chest.json")))
    cube.global_position = Vector3(spot["x"], spot["y"], spot["z"])
    manager.open_personal_chest(cube)
    if not await _wait(func(): return is_instance_valid(manager.chest_panel) and manager.chest_panel.session != "" and not manager.chest_panel.busy, "chest session after recovery", 30.0):
        return -1
    var total: int = 0
    for entry in manager.chest_panel.record.get("chest", []):
        var item = entry.get("item") if entry is Dictionary else null
        if item is PackedInt32Array and item.size() == 3:
            total += item[1]
    return total

func _scn_recover(manager: Node) -> bool:
    await get_tree().create_timer(8.0, true, false, true).timeout
    check(await _wait(func(): return Ref.world.is_all_loaded(), "world loaded after recovery", 60.0), "recovered guest loaded")
    var chest_items: int = -2
    if str(config.get("kill_guest_at", "")) == "chest":
        chest_items = await _open_chest_and_read(manager)
    _mark("recovered", {"items": _item_total(), "chest_items": chest_items, "tally": _item_tally(), "t": Time.get_ticks_msec()})
    return true

func _host_chest_setup(manager: Node) -> void:
    var accesses: Dictionary = Ref.save_file_manager.loaded_file.get_data("coop/chest_access", {}, true).duplicate(true)
    accesses[manager._chest_access_key(manager.get_active_dimension_instance_key(), Vector3i(Ref.player.global_position))] = true
    Ref.save_file_manager.loaded_file.set_data("coop/chest_access", accesses, true)
    _mark("chest", {"x": Ref.player.global_position.x, "y": Ref.player.global_position.y, "z": Ref.player.global_position.z})

func _chest_idle(manager: Node) -> bool:
    return is_instance_valid(manager.chest_panel) and manager.chest_panel.session != "" and not manager.chest_panel.busy and manager.chest_pending_token.is_empty()

# chest_cycle: 10 store/take moves, close in the middle of a pending move, reopen; all 10 granted items must be accounted for.
func _scn_chest_cycle(manager: Node) -> bool:
    _bot_on()
    if role != "guest":
        _host_chest_setup(manager)
        if not await _wait_marker("guest", "chest_done", 300.0):
            return false
        _event("scenario_done", {"name": "chest_cycle"})
        _bot_off()
        return true
    if not await _wait_marker("host", "chest"):
        return false
    var granted := ItemState.new()
    granted.initialize(ItemMap.map(_solid_block_ids()[0]))
    granted.count = 10
    Ref.player_hotbar.set_item(0, granted)
    var started: int = Time.get_ticks_msec()
    var items_total: int = 10
    var chest_total: int = 0
    if await _open_chest_session(manager) == false:
        return false
    for move in range(10):
        manager.chest_panel._select_slot(0)
        manager.chest_panel._request_transfer("Hotbar", 0, move % 2 == 0)
        if move == 4:
            await get_tree().physics_frame
            await get_tree().physics_frame
            manager.close_personal_chest(manager.chest_active_token)
            if not await _wait(func(): return not is_instance_valid(manager.chest_panel) and manager.chest_pending_token.is_empty(), "chest closed with a pending move", 30.0):
                return false
            if await _open_chest_session(manager) == false:
                return false
            continue
        if not await _wait(func(): return _chest_idle(manager), "chest move %d" % move, 30.0):
            return false
    chest_total = _chest_record_total(manager)
    var total: int = _item_total() + chest_total
    check(total == items_total, "chest_cycle conserves items: inventory %d + chest %d = %d of %d" % [_item_total(), chest_total, total, items_total])
    _event("scenario_done", {"name": "chest_cycle", "elapsed_ms": Time.get_ticks_msec() - started, "total": total})
    _mark("chest_done", {"total": total})
    _bot_off()
    return true

func _chest_record_total(manager: Node) -> int:
    var total: int = 0
    for entry in manager.chest_panel.record.get("chest", []):
        var item = entry.get("item") if entry is Dictionary else null
        if item is PackedInt32Array and item.size() == 3:
            total += item[1]
    return total

func _open_chest_session(manager: Node) -> bool:
    var cube := FakeChestBlock.new()
    add_child(cube)
    var spot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scenario.path_join("host_chest.json")))
    cube.global_position = Vector3(spot["x"], spot["y"], spot["z"])
    manager.open_personal_chest(cube)
    return await _wait(func(): return _chest_idle(manager), "chest session", 30.0)

func _run_scenario(manager: Node) -> bool:
    if FileAccess.file_exists(scenario.path_join(role + "_recover.flag")):
        return await _scn_recover(manager)
    var name_value: String = str(config.get("scenario", "mine_tunnel"))
    _event("scenario_start", {"name": name_value})
    var method := "_scn_" + name_value
    if not has_method(method):
        check(false, "unknown scenario " + name_value)
        return false
    return await call(method, manager)

func _install_disk(manager: Node) -> void:
    fault_queue = FaultQueue.new()
    fault_queue.disk = str(config.get("disk", "fast"))
    fault_queue.rng.seed = 777
    manager.save_queue = fault_queue
    print("FRICTION_DISK ", fault_queue.disk)

func _finish_io() -> void:
    if fault_queue != null:
        var file := FileAccess.open(scenario.path_join(role + "_io.json"), FileAccess.WRITE)
        file.store_string(JSON.stringify({"disk": fault_queue.disk, "jobs": fault_queue.records.size(), "failed": fault_queue.failed, "log": fault_queue.records.slice(0, 400)}))
        file.close()
    var pickups := FileAccess.open(scenario.path_join(role + "_pickups.json"), FileAccess.WRITE)
    pickups.store_string(JSON.stringify({"pickup_ms": pickup_ms, "mined": mined, "items": _item_total(), "items0": items0, "drops_left": _drops_left(), "tally": _item_tally(), "drops_tally": _drops_tally(), "spawned": spawned}))
    pickups.close()

func _world_ready() -> bool:
    return Ref.world.load_enabled and Ref.world.is_all_loaded() and not Ref.player.disabled

func _run() -> void:
    if not FileAccess.file_exists(scenario.path_join(".local-coop-scenario")):
        push_error("LOCAL_COOP disposable marker missing")
        get_tree().quit(1)
        return
    if not await _wait(func(): return seeded and Ref.main != null and Ref.main.loaded and Ref.coop_manager != null, "menu startup"):
        return
    var manager = Ref.coop_manager
    _install_disk(manager)
    _configure(manager)
    if role != "guest":
        var files = Ref.save_file_manager
        files.initialize_file()
        var register = files.loaded_file_register
        var settings := {"dimension": 1, "divine": true, "progression_disabled": true, "world_seed": 12345, "find_spawn": false, "reset_world": false, "title": "Disposable friction world"}
        for entry in settings:
            register.set_data(entry, settings[entry], true)
        files.initialize_save_file_directory(register.get_data("uuid"), false)
        files.load_file(register)
        stage = "enter host game"
        await Ref.main.enter_game()
        if not await _wait(_world_ready, "host loaded"):
            return
        _configure(manager)
        if role == "host":
            manager.host_session()
            check(manager._has_live_peer() and multiplayer.is_server(), "actual LAN host transport")
            _mark("ready")
            if not await _wait(func(): return FileAccess.file_exists(scenario.path_join("guest_ready.json")), "guest ready", 90.0):
                return
            if not await _wait(func(): return manager.chunk_authority.lease_epoch > 0 and not manager.lease_busy and _world_ready(), "host initial lease", 60.0):
                return
            _mark("go")
    else:
        if not await _wait(func(): return FileAccess.file_exists(scenario.path_join("host_ready.json")), "host ready", 90.0):
            return
        manager.join_session()
        if not await _wait(func(): return _world_ready() and manager.guest_persistent_ready and manager.client_world_sync_ready and not manager.receiving_host_world and not manager.client_restore_in_progress, "guest snapshot/profile load", 90.0):
            return
        if not await _wait(func(): return manager.chunk_authority.lease_epoch > 0 and not manager.lease_busy and not manager.lease_frozen and not manager.lease_preparing and _world_ready(), "initial runtime lease installed", 30.0):
            return
        _mark("ready", {"key_hash": manager._get_local_player_key().sha256_text()})
        if not await _wait_marker("host", "go"):
            return
    _flush_tele()
    var succeeded: bool = await _run_scenario(manager)
    _flush_tele()
    if not succeeded:
        return
    if role == "guest":
        _mark("scenario_complete")
        manager.disconnect_session(false)
    elif role == "host":
        if not await _wait(func(): return FileAccess.file_exists(scenario.path_join("guest_scenario_complete.json")), "guest finished", 120.0):
            return
        if not await _wait(func(): return manager.admitted_player_keys.is_empty(), "guest disconnected", 60.0):
            return
        check(await manager._shutdown_host_session(false, "friction run finished"), "host shutdown commits world")
    stage = "shutdown"
    if not await _wait(func(): return Ref.world.is_all_loaded(), "finish native loading", 60.0):
        return
    _finish_io()
    await Ref.main.quit_game(true, true)
    var keyboard = get_node_or_null("/root/Main/UI/OnscreenKeyboard")
    if keyboard != null:
        var helper = keyboard.get("KeyListHandler")
        if is_instance_valid(helper) and helper is Node and not helper.is_inside_tree() and helper.get_script().resource_path == "res://addons/onscreenkeyboard/keylist.gd":
            helper.free()
            keyboard.set("KeyListHandler", null)
    _flush_tele()
    _mark("complete", {"checks": checks, "failures": failures})
    print("LOCAL_COOP_RESULT ", role, " ", checks, " checks ", failures, " failures")
    get_tree().quit(1 if failures else 0)
