extends Node


const CONFIG_PATH: String = "user://lucid_blocks_coop_config.json"
const DEFAULT_PORT: int = 24567
const MAX_CLIENTS: int = 4
const SEND_INTERVAL: float = 0.025
const WORLD_STATE_INTERVAL: float = 0.05
const ENTITY_DR_POS_ERR_SQ: float = 0.0225
const ENTITY_DR_KB_ERR_SQ: float = 0.25
const ENTITY_DR_YAW_ERR_DEG: float = 5.0
const ENTITY_DR_HEARTBEAT_SEC: float = 0.25
const ENTITY_VISUAL_STATE_INTERVAL: float = 0.15
const CLIENT_ENTITY_SYNC_GRACE_SEC: float = 0.5
const PERSIST_INTERVAL: float = 1.0
const AUTOSAVE_INTERVAL: float = 12.0
const HOST_TIMEOUT_SECONDS: float = 30.0
const AUTO_RECONNECT_INTERVAL: float = 2.0
const PANEL_WIDTH: float = 224.0
const SNAPSHOT_CHUNK_SIZE: int = 60000
const DEFAULT_AVATAR_ID: String = "default_blocky"
const REMOTE_PROXY_SCENE_PATH: String = "res://coop_mod/remote_player_proxy.tscn"
const HOST_SESSION_MIN_LOAD_RADIUS: int = 96
const HOST_SESSION_MAX_LOAD_RADIUS: int = 96
const HOST_SESSION_EDGE_BUFFER: float = 72.0
const HOST_SESSION_RADIUS_STEP: int = 16
const SHARED_BUBBLE_SOFT_TETHER_DISTANCE: float = 64.0
const SHARED_BUBBLE_HARD_TETHER_DISTANCE: float = 80.0
const SHARED_BUBBLE_TETHER_PULL: float = 10.0
const ENTITY_SYNC_RADIUS: float = 144.0
const DROP_SYNC_RADIUS: float = 96.0
const BREAK_OUTLINE_SCENE_PATH: String = "res://main/entity/behaviors/break_blocks/break_block_outline.tscn"
const DROPPED_ITEM_SCENE_PATH: String = "res://main/items/dropped_item/dropped_item.tscn"
const VISUAL_BALL_SCENE_PATH: String = "res://main/items/held_item/held_ball_thrower/ball.tscn"
const VISUAL_BOLT_SCENE_PATH: String = "res://main/entity/baal/bolt/mini_bolt.tscn"
const VISUAL_PROJECTILE_LIFETIME: float = 5.0
const CLIENT_DROP_CORRECTION_DISTANCE: float = 1.35
const CLIENT_DROP_POSITION_BLEND: float = 0.45
const CLIENT_DROP_VELOCITY_BLEND: float = 0.7
const CLIENT_PREDICTED_DROP_MATCH_DISTANCE: float = 2.5
const CLIENT_PREDICTED_DROP_LIFETIME: float = 1.5
const CLIENT_PENDING_PICKUP_LIFETIME: float = 4.0
const CLIENT_AUTO_PICKUP_RADIUS: float = 2.35
const CLIENT_PREDICTED_DROP_SYNC_GRACE_MS: int = 350
const CLIENT_DROP_MERGE_ANIMATION_DISTANCE: float = 2.6
const CLIENT_DROP_MERGE_ANIMATION_TIME: float = 0.12
const DEBUG_SPAWN_DISTANCE: float = 6.0
const DEBUG_SPAWN_RESOURCE_DIR: String = "res://main/items/data/spawners"
const DEBUG_SPAWN_FALLBACK_IDS: PackedStringArray = [
    "agni", "archangel", "baal", "bee", "blasphemy", "boid", "bubble", "bubblebear", "chicken", "diatom", "egg_bubblebear", "egg_chicken", "fish", "floating_fish", "fruit_girl", "fungus_bubblebear", "gel", "glaggler", "golem", "hamsa", "kali", "kodama", "leviathan", "manikin", "meeshuu", "metal_gel", "metal_golem", "mimic", "mini_gel", "moccos", "ofanim", "plastic_sheep", "preta", "shark", "sheep", "sunny", "vyrm", "wildebeest", "worm", "yhvh"
]
const REVIVE_RADIUS: float = 3.2
const REVIVE_HOLD_TIME: float = 1.6
const DOWNED_VOID_Y: float = -96.0
const DOWNED_REVIVER_GRACE_SEC: float = 2.0
const ENABLE_ENTITY_SYNC: bool = true


var config: Dictionary = {
    "address": "127.0.0.1",
    "port": DEFAULT_PORT,
    "avatar_id": DEFAULT_AVATAR_ID,
}

var peer_states: Dictionary = {}
var markers: Dictionary = {}
var send_timer: float = 0.0
var world_state_timer: float = 0.0
var persist_timer: float = 0.0
var autosave_timer: float = 0.0
var status_message: String = "Idle"
var panel_visible: bool = false
var restore_capture_on_close: bool = false
var receiving_host_world: bool = false
var incoming_snapshot_register_json: String = ""
var incoming_snapshot_chunk_count: int = 0
var incoming_snapshot_chunks: Dictionary = {}
var incoming_snapshot_host_position: Vector3 = Vector3.ZERO
var incoming_snapshot_follow_host_position: bool = true
var remote_break_outlines: Dictionary = {}
var synced_entities: Dictionary = {}
var synced_dropped_items: Dictionary = {}
var client_world_sync_ready: bool = false
var coop_player_death_hooked: bool = false
var coop_player_death_hooked_instance_id: int = 0
var local_fake_death_pending: bool = false
var local_fake_death_save_override: Dictionary = {}
var local_fake_death_respawn_target: Vector3 = Vector3.ZERO
var local_fake_death_respawn_target_valid: bool = false
var clear_fake_death_override_after_shutdown: bool = false
var handling_client_respawn: bool = false
var handling_host_respawn: bool = false
var host_respawning: bool = false
var remote_host_respawning: bool = false
var host_respawn_sequence: int = 0
var last_local_world_authority: bool = true
var session_load_radius_applied: bool = false
var session_previous_instance_radius: int = -1
var session_previous_buffer_instance_radius: int = -1
var local_quit_in_progress: bool = false
var guest_persistent_ready: bool = false
var autosave_in_progress: bool = false
var last_host_contact_time: int = 0
var last_sent_client_state_hash: int = 0
var client_state_heartbeat_timer: float = 0.0
var local_state_sequence: int = 0
var host_snapshot_sequence: int = 0
var last_received_host_snapshot_sequence: int = -1
var client_restore_in_progress: bool = false
var client_menu_kick_pending: bool = false
var reconnect_pending: bool = false
var reconnect_attempt_count: int = 0
var reconnect_retry_timer: float = 0.0
var reconnect_reason: String = ""
var host_rehost_pending: bool = false
var host_rehost_port: int = DEFAULT_PORT
var suppress_local_game_quit_session_shutdown: bool = false
var pending_remote_block_changes: Dictionary = {}
var pending_remote_water_changes: Dictionary = {}
var pending_remote_fire_changes: Dictionary = {}
var remote_player_proxies: Dictionary = {}
var spawn_anchor_index: int = 0
var host_world_state_sequence: int = 0
var client_last_world_state_sequence: int = -1
var host_entity_update_counter: int = 0
var tracked_root_entities: Array = []
var tracked_root_drops: Array = []
var animation_tree_parameter_cache: Dictionary = {}
var pending_pickup_receipts: Array = []
var client_collected_drop_uuids: Dictionary = {}
var reconnect_restore_capture_on_close: bool = false
var entity_interp_map: Dictionary = {}
var host_entity_last_sent: Dictionary = {}
var host_entity_activity_refresh_timer: float = 0.0
var host_entity_activity_override_active: bool = false
var host_server_time: float = 0.0
var client_server_time: float = 0.0
var client_server_time_initialized: bool = false
var debug_spawn_catalog: Dictionary = {}
var local_downed: bool = false
var local_downed_position: Vector3 = Vector3.ZERO
var local_downed_position_valid: bool = false
var local_downed_started_msec: int = 0
var revive_hold_progress: float = 0.0
var revive_target_peer_id: int = -1
var revive_request_pending: bool = false

var hud: CanvasLayer
var overlay: Control
var panel: PanelContainer
var panel_scroll: ScrollContainer
var panel_column: VBoxContainer
var death_overlay: Control
var death_overlay_title: Label
var death_overlay_subtitle: Label
var revive_prompt_label: Label
var spawn_browser_overlay: Control
var spawn_browser_panel: PanelContainer
var spawn_browser_search_input: LineEdit
var spawn_browser_list: ItemList
var spawn_browser_hint_label: Label
var spawn_browser_restore_capture_on_close: bool = false
var spawn_browser_entries: PackedStringArray = PackedStringArray()
var reconnect_overlay: Control
var reconnect_overlay_title: Label
var reconnect_overlay_subtitle: Label
var local_ip_label: Label
var status_label: Label
var address_input: LineEdit
var port_input: SpinBox


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _load_config()
    _build_hud()
    if get_viewport() != null and not get_viewport().size_changed.is_connected(_refresh_overlay_layout):
        get_viewport().size_changed.connect(_refresh_overlay_layout)
    call_deferred("_refresh_overlay_layout")
    call_deferred("_install_player_death_hook")

    if is_instance_valid(Ref.main) and not Ref.main.game_quit.is_connected(_on_local_game_quit):
        Ref.main.game_quit.connect(_on_local_game_quit)
    if is_instance_valid(Ref.main) and not Ref.main.world_loaded.is_connected(_on_local_world_loaded):
        Ref.main.world_loaded.connect(_on_local_world_loaded)

    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)

    get_tree().get_root().child_entered_tree.connect(_on_root_child_entered)
    get_tree().get_root().child_exiting_tree.connect(_on_root_child_exiting)
    _rebuild_tracked_root_runtime_lists()

    print("[lucid-blocks-coop] manager ready")
    _update_status_text()


func _input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    if not event.pressed or event.echo:
        return

    var focus_owner: Control = get_viewport().gui_get_focus_owner()
    var typing_in_field: bool = focus_owner is LineEdit or focus_owner is TextEdit
    if typing_in_field and event.keycode != KEY_ESCAPE:
        return

    if Ref.command_chat_manager != null and Ref.command_chat_manager.has_method("is_command_chat_open") and Ref.command_chat_manager.is_command_chat_open():
        return

    if spawn_browser_overlay != null and spawn_browser_overlay.visible:
        match event.keycode:
            KEY_ESCAPE, KEY_F10:
                toggle_spawn_browser(false)
                get_viewport().set_input_as_handled()
        return

    match event.keycode:
        KEY_F5:
            toggle_panel()
        KEY_ESCAPE:
            if panel_visible:
                toggle_panel(false)
        KEY_F10:
            toggle_spawn_browser()
        KEY_F6:
            host_session()
        KEY_F7:
            if event.shift_pressed:
                _load_config(true)
            else:
                join_session()
        KEY_F8:
            leave_session()
        KEY_F9:
            teleport_to_connected_player()


func _rebuild_tracked_root_runtime_lists() -> void:
    tracked_root_entities.clear()
    tracked_root_drops.clear()
    for child in get_tree().get_root().get_children():
        _register_root_runtime_node(child)


func _register_root_runtime_node(node: Node) -> void:
    if node is Entity and not (node is Player) and not is_remote_player_proxy(node):
        if not tracked_root_entities.has(node):
            tracked_root_entities.append(node)
    elif node is DroppedItem:
        if not tracked_root_drops.has(node):
            tracked_root_drops.append(node)


func _unregister_root_runtime_node(node: Node) -> void:
    tracked_root_entities.erase(node)
    tracked_root_drops.erase(node)


func _on_root_child_entered(node: Node) -> void:
    _register_root_runtime_node(node)


func _on_root_child_exiting(node: Node) -> void:
    _unregister_root_runtime_node(node)


func _get_live_tracked_entities() -> Array:
    var live: Array = []
    for node in tracked_root_entities:
        if is_instance_valid(node) and node.is_inside_tree() and not is_remote_player_proxy(node):
            live.append(node)
    tracked_root_entities = live
    return tracked_root_entities


func _get_sync_scene_path(node: Node) -> String:
    if not is_instance_valid(node):
        return ""
    var scene_path: String = str(node.scene_file_path)
    if scene_path != "":
        return scene_path
    return str(node.get_meta("coop_source_scene_path", ""))


func _is_syncable_entity_node(node: Node) -> bool:
    return node is Entity and not (node is Player) and not is_remote_player_proxy(node)


func _get_live_tracked_drops() -> Array:
    var live: Array = []
    for node in tracked_root_drops:
        if is_instance_valid(node) and node.is_inside_tree():
            live.append(node)
    tracked_root_drops = live
    return tracked_root_drops


func _enforce_coop_pause_override() -> void:
    if not _has_live_peer() or get_tree() == null or not get_tree().paused:
        return
    if Ref.game_menu == null:
        return
    if int(Ref.game_menu.state) != 4:
        return
    get_tree().paused = false


func _physics_process(delta: float) -> void:
    _enforce_coop_pause_override()
    _refresh_world_authority_mode()
    _refresh_host_entity_activity_override(delta)
    _refresh_session_load_radius()
    _flush_pending_remote_world_changes()
    _tick_entity_interpolation(delta)
    _tick_client_synced_entity_visuals(delta)
    _tick_local_downed_state(delta)
    _tick_revive_interaction(delta)
    _enforce_shared_bubble_tether(delta)
    _cleanup_client_prediction_state()

    if reconnect_pending:
        _tick_reconnect(delta)

    if not _has_live_peer():
        _hide_all_markers()
        _clear_remote_break_outlines()
        return

    send_timer += delta
    world_state_timer += delta
    persist_timer += delta
    autosave_timer += delta
    client_state_heartbeat_timer += delta
    if multiplayer.is_server() and (WORLD_STATE_INTERVAL <= 0.0 or world_state_timer >= WORLD_STATE_INTERVAL):
        world_state_timer = 0.0
        host_world_state_sequence += 1
        for peer_id in peer_states.keys():
            var int_peer_id: int = int(peer_id)
            if int_peer_id == 1:
                continue
            var peer_state: Dictionary = peer_states[peer_id]
            if not bool(peer_state.get("active", false)):
                continue
            server_world_state.rpc_id(
                int_peer_id,
                host_world_state_sequence,
                _capture_host_drop_snapshots(peer_state.get("position", Ref.player.global_position)),
                _capture_host_entity_snapshots(peer_state.get("position", Ref.player.global_position))
            )
    elif not multiplayer.is_server() and client_world_sync_ready and guest_persistent_ready and persist_timer >= PERSIST_INTERVAL:
        persist_timer = 0.0
        _send_persistent_state_to_host()

    if multiplayer.is_server() and autosave_timer >= AUTOSAVE_INTERVAL:
        autosave_timer = 0.0
        _autosave_host_world_if_needed()

    if _has_host_timed_out():
        print("[lucid-blocks-coop] host heartbeat timed out")
        if not local_quit_in_progress:
            _begin_reconnect_flow("Connection timed out")
        return

    if send_timer < SEND_INTERVAL:
        return
    send_timer = 0.0

    var local_state: Dictionary = _capture_local_state_for_send()
    if multiplayer.is_server():
        peer_states[1] = local_state
        _refresh_markers(peer_states, multiplayer.get_unique_id())
        host_snapshot_sequence += 1
        server_snapshot.rpc(host_snapshot_sequence, _serialize_peer_states())
    else:
        var state_hash: int = _hash_client_state(local_state)
        if state_hash != last_sent_client_state_hash or client_state_heartbeat_timer >= 0.25:
            last_sent_client_state_hash = state_hash
            client_state_heartbeat_timer = 0.0
            submit_client_state.rpc_id(
                1,
                int(local_state.get("sequence", 0)),
                local_state.get("active", false),
                bool(local_state.get("downed", false)),
                local_state.get("dimension", -1),
                str(local_state.get("dimension_instance_key", "")),
                str(local_state.get("pocket_owner_key", "")),
                local_state.get("position", Vector3.ZERO),
                local_state.get("yaw", 0.0),
                local_state.get("pitch", 0.0),
                local_state.get("crouching", false),
                local_state.get("grounded", true),
                local_state.get("move_speed", 0.0),
                bool(local_state.get("under_water", false)),
                local_state.get("held_item_id", -1),
                local_state.get("action_state", 0),
                str(local_state.get("name", "guest")),
                str(local_state.get("player_key", "")),
                str(local_state.get("avatar_id", DEFAULT_AVATAR_ID)),
                local_state.get("skin_color", Color.WHITE),
                bool(local_state.get("breaking", false)),
                local_state.get("break_position", Vector3i.ZERO),
                int(local_state.get("break_block_id", 0)),
                float(local_state.get("break_progress", 0.0))
            )


func toggle_panel(force_visible: Variant = null) -> void:
    var next_visible: bool = not panel_visible if force_visible == null else bool(force_visible)
    if next_visible == panel_visible:
        return

    panel_visible = next_visible
    panel.visible = panel_visible

    if panel_visible:
        _close_pause_menu_if_open()
        restore_capture_on_close = MouseHandler.captured
        MouseHandler.release()
        _refresh_local_ip_label()
        _sync_inputs_from_config()
        _refresh_overlay_layout()
        address_input.grab_focus()
        address_input.caret_column = address_input.text.length()
    else:
        _apply_ui_to_config()
        get_viewport().gui_release_focus()
        if restore_capture_on_close:
            MouseHandler.capture()

    _update_status_text()


func _refresh_overlay_layout() -> void:
    if get_viewport() == null:
        return

    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    if panel != null and panel_column != null:
        var panel_min_size: Vector2 = panel_column.get_combined_minimum_size() + Vector2(16.0, 16.0)
        var panel_width: float = clampf(maxf(PANEL_WIDTH, panel_min_size.x), 160.0, maxf(160.0, viewport_size.x - 12.0))
        var panel_height: float = clampf(panel_min_size.y, 96.0, maxf(96.0, viewport_size.y - 24.0))
        panel.offset_left = -panel_width * 0.5
        panel.offset_right = panel_width * 0.5
        panel.offset_top = 12.0
        panel.offset_bottom = 12.0 + panel_height

    if spawn_browser_panel != null:
        var browser_width: float = clampf(420.0, 180.0, maxf(180.0, viewport_size.x - 16.0))
        var browser_height: float = clampf(420.0, 160.0, maxf(160.0, viewport_size.y - 16.0))
        spawn_browser_panel.custom_minimum_size = Vector2(browser_width, browser_height)


func host_session() -> void:
    if not _can_share_loaded_world():
        status_message = "Open LAN from inside a loaded world"
        _update_status_text()
        return

    local_quit_in_progress = false
    local_fake_death_save_override.clear()
    local_fake_death_respawn_target_valid = false
    clear_fake_death_override_after_shutdown = false
    _clear_local_downed_state()
    guest_persistent_ready = true
    last_host_contact_time = Time.get_ticks_msec()
    autosave_timer = 0.0
    client_state_heartbeat_timer = 0.0
    last_sent_client_state_hash = 0
    host_rehost_pending = false
    host_rehost_port = int(config.get("port", DEFAULT_PORT))
    _apply_ui_to_config()
    disconnect_session(false)

    var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
    var err: Error = peer.create_server(int(config.get("port", DEFAULT_PORT)), MAX_CLIENTS)
    if err != OK:
        status_message = "Host failed (%s)" % err
        push_warning("[lucid-blocks-coop] host failed: %s" % err)
        _update_status_text()
        return

    multiplayer.multiplayer_peer = peer
    peer_states.clear()
    _install_player_death_hook()
    status_message = "Hosting on port %s" % int(config.get("port", DEFAULT_PORT))
    print("[lucid-blocks-coop] %s" % status_message)
    _update_status_text()


func join_session() -> void:
    local_quit_in_progress = false
    local_fake_death_save_override.clear()
    local_fake_death_respawn_target_valid = false
    clear_fake_death_override_after_shutdown = false
    _clear_local_downed_state()
    guest_persistent_ready = false
    last_host_contact_time = 0
    autosave_timer = 0.0
    client_state_heartbeat_timer = 0.0
    last_sent_client_state_hash = 0
    host_rehost_pending = false
    _apply_ui_to_config()
    disconnect_session(false)

    var address: String = str(config.get("address", "127.0.0.1")).strip_edges()
    var port: int = int(config.get("port", DEFAULT_PORT))
    reconnect_pending = false
    reconnect_attempt_count = 0
    reconnect_retry_timer = 0.0
    _set_reconnect_overlay_visible(false)
    var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
    var err: Error = peer.create_client(address, port)
    if err != OK:
        status_message = "Join failed (%s)" % err
        push_warning("[lucid-blocks-coop] join failed: %s" % err)
        _update_status_text()
        return

    multiplayer.multiplayer_peer = peer
    peer_states.clear()
    _install_player_death_hook()
    status_message = "Joining %s:%s" % [address, port]
    print("[lucid-blocks-coop] %s" % status_message)
    _update_status_text()


func disconnect_session(announce: bool = true) -> void:
    _restore_original_death_handler()
    var local_fake_death_active: bool = local_fake_death_pending or handling_host_respawn or handling_client_respawn or host_respawning
    var local_downed_active: bool = local_downed
    if _has_live_peer() and not multiplayer.is_server() and guest_persistent_ready:
        _send_persistent_state_to_host()
    if local_fake_death_active and local_fake_death_save_override.is_empty():
        local_fake_death_save_override = _build_local_fake_death_save_overrides()
    if handling_host_respawn or host_respawning:
        host_respawn_sequence += 1
    local_fake_death_pending = false
    handling_host_respawn = false
    handling_client_respawn = false
    host_respawning = false
    remote_host_respawning = false
    client_restore_in_progress = false
    last_received_host_snapshot_sequence = -1
    _set_death_overlay_visible(false)
    if is_instance_valid(Ref.player):
        if local_fake_death_active:
            _stabilize_local_player_after_fake_death()
        else:
            Ref.player.disabled = false
            Ref.player.invincible = bool(Ref.main.creative) if is_instance_valid(Ref.main) else false
            Ref.player.invincible_temporary = false
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

    peer_states.clear()
    _clear_markers()
    _clear_remote_break_outlines()
    send_timer = 0.0
    world_state_timer = 0.0
    persist_timer = 0.0
    autosave_timer = 0.0
    client_state_heartbeat_timer = 0.0
    host_entity_activity_refresh_timer = 0.0
    _clear_host_entity_activity_override()
    synced_entities.clear()
    synced_dropped_items.clear()
    host_entity_last_sent.clear()
    client_world_sync_ready = false
    guest_persistent_ready = false
    client_menu_kick_pending = false
    last_host_contact_time = 0
    last_sent_client_state_hash = 0
    reconnect_retry_timer = 0.0
    pending_remote_block_changes.clear()
    pending_remote_water_changes.clear()
    pending_remote_fire_changes.clear()
    _clear_local_downed_state()

    if announce:
        status_message = "Disconnected"
        print("[lucid-blocks-coop] disconnected")
    else:
        status_message = "Idle"

    _update_status_text()

    if local_downed_active and not local_quit_in_progress and is_instance_valid(Ref.main):
        Ref.main.player_death.call_deferred()


func leave_session() -> void:
    var should_kick_to_menu: bool = not multiplayer.is_server() and (reconnect_pending or (reconnect_overlay != null and reconnect_overlay.visible))
    reconnect_pending = false
    reconnect_attempt_count = 0
    reconnect_retry_timer = 0.0
    reconnect_reason = ""
    host_rehost_pending = false
    _set_reconnect_overlay_visible(false)
    _close_pause_menu_if_open()

    if not _has_live_peer():
        disconnect_session()
        if should_kick_to_menu:
            _queue_client_main_menu_kick()
        return

    local_quit_in_progress = true
    if multiplayer.is_server():
        if is_local_player_fake_dead():
            _abort_host_respawn(false, false)
        clear_fake_death_override_after_shutdown = true
        _shutdown_host_session.call_deferred(false, "Host ended the session")
        return

    if guest_persistent_ready:
        _send_persistent_state_to_host(true)
        guest_persistent_ready = false
    disconnect_session(false)
    status_message = "Left host session"
    _update_status_text()
    _queue_client_main_menu_kick()


func _has_live_peer() -> bool:
    return multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func has_active_session() -> bool:
    return _has_live_peer()


func is_death_override_active() -> bool:
    return has_active_session()


func request_player_death_intercept(_player: Entity = null) -> bool:
    if not is_death_override_active():
        return false
    local_quit_in_progress = false
    local_fake_death_save_override.clear()
    local_fake_death_respawn_target_valid = false
    clear_fake_death_override_after_shutdown = false
    local_fake_death_pending = false
    handling_client_respawn = false
    handling_host_respawn = false
    host_respawning = false
    remote_host_respawning = false
    local_downed = true
    local_downed_position_valid = false
    local_downed_started_msec = Time.get_ticks_msec()
    revive_hold_progress = 0.0
    revive_target_peer_id = -1
    revive_request_pending = false
    return true


func is_local_player_downed() -> bool:
    return local_downed


func _clear_local_downed_state() -> void:
    local_downed = false
    local_downed_position = Vector3.ZERO
    local_downed_position_valid = false
    local_downed_started_msec = 0
    revive_hold_progress = 0.0
    revive_target_peer_id = -1
    revive_request_pending = false
    if revive_prompt_label != null:
        revive_prompt_label.visible = false


func _resolve_local_downed_position() -> Vector3:
    if not _can_sample_player():
        return Vector3.ZERO

    var current_position: Vector3 = Ref.player.global_position
    var fallback_position: Vector3 = _resolve_default_respawn_fallback_position(current_position)
    if _has_live_peer():
        var remote_anchor: Vector3 = _get_remote_respawn_anchor(multiplayer.is_server(), fallback_position)
        fallback_position = _find_safe_respawn_position_near(remote_anchor, fallback_position)

    if current_position.y <= DOWNED_VOID_Y:
        return fallback_position

    var centered_current: Vector3 = current_position.floor() + Vector3(0.5, 0.0, 0.5)
    if _is_safe_respawn_position(centered_current):
        return centered_current
    return _find_safe_respawn_position_near(centered_current, fallback_position)


func _has_same_instance_reviver_available(ignore_peer_id: int = -1) -> bool:
    if not _has_live_peer() or not _can_sample_player():
        return false

    var active_instance_key: String = get_active_dimension_instance_key()
    for peer_id in peer_states.keys():
        var int_peer_id: int = int(peer_id)
        if int_peer_id == ignore_peer_id:
            continue
        var state: Dictionary = peer_states[peer_id]
        if not bool(state.get("active", false)):
            continue
        if bool(state.get("downed", false)):
            continue
        if str(state.get("dimension_instance_key", "")) != active_instance_key:
            continue
        return true
    return false


func _enter_local_downed_state() -> void:
    if not _can_sample_player():
        return

    local_downed = true
    local_downed_position_valid = false
    local_downed_started_msec = Time.get_ticks_msec()
    revive_hold_progress = 0.0
    revive_target_peer_id = -1
    revive_request_pending = false
    _stop_local_player_actions()
    Ref.player.dead = false
    Ref.player.health = maxi(1, Ref.player.health)
    Ref.player.invincible = true
    Ref.player.invincible_temporary = true
    Ref.player.disabled = true
    if "flying" in Ref.player:
        Ref.player.flying = false

    local_downed_position = _resolve_local_downed_position()
    local_downed_position_valid = true
    _teleport_local_player_exact(local_downed_position)

    if panel_visible:
        toggle_panel(false)

    _set_death_overlay_visible(true, "Hold on. Your partner can revive you.", "DOWNED")
    status_message = "Downed - waiting for revive"
    _update_status_text()
    _broadcast_local_state_now()


func _finish_local_revive(revive_position: Vector3, source_label: String = "Partner") -> void:
    if not _can_sample_player():
        return

    _clear_local_downed_state()
    Ref.player.revive()
    Ref.player.health = maxi(1, int(ceil(float(Ref.player.max_health) * 0.5)))
    Ref.player.dead = false
    Ref.player.disabled = false
    Ref.player.invincible = bool(Ref.main.creative)
    Ref.player.invincible_temporary = false
    Ref.player.make_invincible_temporary()
    _teleport_local_player_exact(revive_position)
    Ref.player.consume_actions()
    _set_death_overlay_visible(false)
    status_message = "%s revived you" % source_label
    _update_status_text()
    _broadcast_local_state_now()


func _commit_local_real_death(reason: String = "") -> void:
    _clear_local_downed_state()
    local_fake_death_pending = false
    handling_client_respawn = false
    handling_host_respawn = false
    host_respawning = false
    remote_host_respawning = false
    local_quit_in_progress = false
    if is_instance_valid(Ref.player):
        Ref.player.invincible = false
        Ref.player.invincible_temporary = false
        Ref.player.disabled = false
        Ref.player.dead = false
    if panel_visible:
        toggle_panel(false)
    _set_death_overlay_visible(false)
    if reason != "":
        status_message = reason
        _update_status_text()
    if is_instance_valid(Ref.main):
        Ref.main.player_death.call_deferred()


func _tick_local_downed_state(_delta: float) -> void:
    if not local_downed or not _can_sample_player():
        return

    if local_downed_position_valid:
        Ref.player.global_position = local_downed_position
    _reset_local_player_motion()
    Ref.player.dead = false
    Ref.player.disabled = true

    var grace_active: bool = local_downed_started_msec > 0 and (Time.get_ticks_msec() - local_downed_started_msec) < int(DOWNED_REVIVER_GRACE_SEC * 1000.0)
    if _has_live_peer() and not grace_active and not _has_same_instance_reviver_available(multiplayer.get_unique_id()):
        _commit_local_real_death("No partner available to revive you")


func _get_revivable_peer_state() -> Dictionary:
    if not _has_live_peer() or not _can_sample_player() or is_local_player_downed():
        return {}

    var active_instance_key: String = get_active_dimension_instance_key()
    var nearest_state: Dictionary = {}
    var nearest_peer_id: int = -1
    var nearest_distance_squared: float = REVIVE_RADIUS * REVIVE_RADIUS
    for peer_id in peer_states.keys():
        var int_peer_id: int = int(peer_id)
        if int_peer_id == multiplayer.get_unique_id():
            continue
        var state: Dictionary = peer_states[peer_id]
        if not bool(state.get("active", false)):
            continue
        if not bool(state.get("downed", false)):
            continue
        if str(state.get("dimension_instance_key", "")) != active_instance_key:
            continue
        var peer_position: Vector3 = state.get("position", Ref.player.global_position)
        var distance_squared: float = Ref.player.global_position.distance_squared_to(peer_position)
        if distance_squared > nearest_distance_squared:
            continue
        nearest_distance_squared = distance_squared
        nearest_state = state.duplicate(true)
        nearest_peer_id = int_peer_id
    if nearest_peer_id == -1:
        return {}
    nearest_state["peer_id"] = nearest_peer_id
    return nearest_state


func _tick_revive_interaction(delta: float) -> void:
    if revive_prompt_label == null:
        return

    revive_prompt_label.visible = false
    if revive_request_pending or not _can_sample_player() or panel_visible or is_local_player_downed() or Ref.player.dead or Ref.player.disabled:
        revive_hold_progress = 0.0
        revive_target_peer_id = -1
        return

    var revive_state: Dictionary = _get_revivable_peer_state()
    if revive_state.is_empty():
        revive_hold_progress = 0.0
        revive_target_peer_id = -1
        return

    var target_peer_id: int = int(revive_state.get("peer_id", -1))
    if target_peer_id != revive_target_peer_id:
        revive_target_peer_id = target_peer_id
        revive_hold_progress = 0.0

    var target_name: String = str(revive_state.get("name", "Partner"))
    var revive_pressed: bool = Input.is_physical_key_pressed(KEY_F)
    if revive_pressed:
        revive_hold_progress = minf(REVIVE_HOLD_TIME, revive_hold_progress + delta)
    else:
        revive_hold_progress = maxf(0.0, revive_hold_progress - delta * 1.5)

    revive_prompt_label.visible = true
    revive_prompt_label.text = "Hold F to revive %s (%d%%)" % [target_name, int(round((revive_hold_progress / REVIVE_HOLD_TIME) * 100.0))]

    if revive_hold_progress < REVIVE_HOLD_TIME:
        return

    revive_hold_progress = 0.0
    revive_request_pending = true
    if multiplayer.is_server():
        _host_attempt_revive(multiplayer.get_unique_id(), target_peer_id)
    else:
        request_revive_peer.rpc_id(1, target_peer_id)


func _get_peer_state_for_revive(peer_id: int) -> Dictionary:
    if peer_id == 1 and multiplayer.is_server():
        return _capture_local_state()
    return peer_states.get(peer_id, {})


func _get_peer_revive_position(peer_id: int, state: Dictionary) -> Vector3:
    if peer_id == 1 and multiplayer.is_server() and local_downed_position_valid:
        return local_downed_position
    return state.get("position", Ref.player.global_position if _can_sample_player() else Vector3.ZERO)


func _resolve_peer_revive_position(peer_id: int, state: Dictionary) -> Vector3:
    var anchor_position: Vector3 = _get_peer_revive_position(peer_id, state)
    return _find_safe_respawn_position_near(anchor_position, anchor_position)


func _host_attempt_revive(sender_id: int, target_peer_id: int) -> void:
    if not multiplayer.is_server() or target_peer_id <= 0:
        return

    var sender_state: Dictionary = _get_peer_state_for_revive(sender_id)
    var target_state: Dictionary = _get_peer_state_for_revive(target_peer_id)
    if sender_state.is_empty() or target_state.is_empty():
        _send_revive_feedback(sender_id, "Revive failed")
        return

    var sender_instance_key: String = str(sender_state.get("dimension_instance_key", ""))
    if sender_instance_key == "" or sender_instance_key != str(target_state.get("dimension_instance_key", "")):
        _send_revive_feedback(sender_id, "Revive failed: not in the same area")
        return

    if bool(sender_state.get("downed", false)):
        _send_revive_feedback(sender_id, "Revive failed: you are downed")
        return
    if not bool(target_state.get("downed", false)):
        _send_revive_feedback(sender_id, "Revive failed: target is already up")
        return

    var sender_position: Vector3 = _get_peer_revive_position(sender_id, sender_state)
    var target_position: Vector3 = _get_peer_revive_position(target_peer_id, target_state)
    if sender_position.distance_squared_to(target_position) > REVIVE_RADIUS * REVIVE_RADIUS:
        _send_revive_feedback(sender_id, "Revive failed: get closer")
        return

    var reviver_name: String = str(sender_state.get("name", "Partner"))
    var revive_position: Vector3 = _resolve_peer_revive_position(target_peer_id, target_state)
    if target_peer_id == 1:
        _finish_local_revive(revive_position, reviver_name)
    else:
        force_peer_revive.rpc_id(target_peer_id, revive_position, reviver_name)

    _send_revive_feedback(sender_id, "Revived %s" % str(target_state.get("name", "partner")))


func _send_revive_feedback(peer_id: int, message: String) -> void:
    if peer_id == multiplayer.get_unique_id():
        revive_request_pending = false
        status_message = message
        _update_status_text()
        return
    receive_revive_feedback.rpc_id(peer_id, message)


@rpc("any_peer", "call_remote", "reliable")
func request_revive_peer(target_peer_id: int) -> void:
    if not multiplayer.is_server():
        return
    var sender_id: int = multiplayer.get_remote_sender_id()
    if sender_id <= 0:
        return
    _host_attempt_revive(sender_id, target_peer_id)


@rpc("authority", "call_remote", "reliable")
func force_peer_revive(revive_position: Vector3, reviver_name: String) -> void:
    if multiplayer.is_server():
        return
    _mark_host_contact()
    _finish_local_revive(revive_position, reviver_name)


@rpc("authority", "call_remote", "reliable")
func receive_revive_feedback(message: String) -> void:
    revive_request_pending = false
    revive_hold_progress = 0.0
    revive_target_peer_id = -1
    status_message = message
    _update_status_text()


func open_dimension_instance(target_dimension: int, target_pocket_owner_key: String = "") -> void:
    _open_dimension_instance_async.call_deferred(target_dimension, target_pocket_owner_key)


func _open_dimension_instance_async(target_dimension: int, target_pocket_owner_key: String = "") -> void:
    if not _can_sample_player():
        return

    var pocket_owner_key: String = target_pocket_owner_key.strip_edges()
    if target_dimension == int(LucidBlocksWorld.Dimension.POCKET) and pocket_owner_key == "":
        pocket_owner_key = _get_local_player_key()

    if _has_live_peer() and not multiplayer.is_server():
        _send_persistent_state_to_host()
        request_dimension_world_snapshot.rpc_id(1, target_dimension, pocket_owner_key)
        status_message = "Requesting world sync"
        _update_status_text()
        return

    _set_loaded_dimension_instance(target_dimension, pocket_owner_key)
    await Ref.main.teleport_to_dimension(target_dimension)


func _set_loaded_dimension_instance(target_dimension: int, target_pocket_owner_key: String = "") -> void:
    if Ref.save_file_manager == null or Ref.save_file_manager.loaded_file_register == null:
        return

    Ref.save_file_manager.loaded_file_register.set_data("dimension", target_dimension, true)
    if target_dimension == int(LucidBlocksWorld.Dimension.POCKET):
        Ref.save_file_manager.loaded_file_register.set_data("pocket_owner_key", target_pocket_owner_key, true)
    else:
        Ref.save_file_manager.loaded_file_register.set_data("pocket_owner_key", "", true)


func teleport_to_connected_player() -> void:
    if not _can_sample_player():
        return

    var target_peer_id: int = -1
    var target_state: Dictionary = {}
    for peer_id in peer_states.keys():
        var int_peer_id: int = int(peer_id)
        if int_peer_id == multiplayer.get_unique_id():
            continue

        var state: Dictionary = peer_states[peer_id]
        if not bool(state.get("active", false)):
            continue
        if str(state.get("dimension_instance_key", "")) != get_active_dimension_instance_key():
            continue

        target_peer_id = int_peer_id
        target_state = state
        break

    if target_peer_id == -1:
        for peer_id in peer_states.keys():
            var int_peer_id: int = int(peer_id)
            if int_peer_id == multiplayer.get_unique_id():
                continue
            var state: Dictionary = peer_states[peer_id]
            if not bool(state.get("active", false)):
                continue
            target_peer_id = int_peer_id
            target_state = state
            break

    if target_peer_id == -1:
        status_message = "No connected player to teleport to"
        _update_status_text()
        return

    if str(target_state.get("dimension_instance_key", "")) != get_active_dimension_instance_key():
        request_host_world_snapshot.rpc_id(1)
        status_message = "Resyncing to host world"
        _update_status_text()
        return

    _teleport_local_player_near(target_state.get("position", Ref.player.global_position))
    status_message = "Teleported to peer %s" % target_peer_id
    _update_status_text()


func execute_command(raw_text: String) -> void:
    var text: String = raw_text.strip_edges()
    if text == "":
        return

    var parts: PackedStringArray = text.split(" ", false)
    var command: String = parts[0].to_lower()

    match command:
        "/tp":
            _execute_tp_command(parts)
        "/gamemode", "/gm":
            _execute_gamemode_command(parts)
        "/spawn":
            _execute_spawn_command(parts)
        "/spawnlist":
            _execute_spawnlist_command()
        "/spawnmenu", "/mobs":
            _execute_spawnmenu_command(parts)
        "/pocket":
            status_message = "Pocket dimensions are disabled in tonight's stable build"
            _update_status_text()
        "/visit":
            status_message = "Pocket visits are disabled in tonight's stable build"
            _update_status_text()
        "/host", "/lan":
            if parts.size() >= 2 and parts[1].is_valid_int():
                config["port"] = clampi(int(parts[1]), 1, 65535)
                _sync_inputs_from_config()
            host_session()
        "/join":
            if parts.size() >= 2:
                config["address"] = parts[1]
            if parts.size() >= 3 and parts[2].is_valid_int():
                config["port"] = clampi(int(parts[2]), 1, 65535)
            _sync_inputs_from_config()
            join_session()
        "/avatar":
            if parts.size() < 2:
                status_message = "Usage: /avatar <id>"
            else:
                config["avatar_id"] = _normalize_avatar_id(parts[1])
                _save_config()
                status_message = "Avatar set to %s" % config["avatar_id"]
            _update_status_text()
        _:
            status_message = "Unknown command: %s" % text
            _update_status_text()


func get_command_autocomplete_entries(raw_text: String) -> Array:
    var text: String = raw_text.strip_edges()
    var entries: Array = []
    if not text.begins_with("/"):
        return entries

    if text == "/":
        return _get_root_command_autocomplete_entries("")

    var body: String = text.substr(1)
    var has_space: bool = body.contains(" ")
    var command_body: String = body.get_slice(" ", 0).to_lower()
    var argument_body: String = ""
    if has_space:
        argument_body = body.substr(command_body.length() + 1).strip_edges()

    if not has_space:
        if command_body == "tp":
            return _get_tp_command_autocomplete_entries("")
        if command_body == "spawnmenu" or command_body == "mobs":
            return [_make_command_autocomplete_entry("/spawnmenu", "/spawnmenu", "Open the mob spawn browser")]
        return _get_root_command_autocomplete_entries(command_body)

    match command_body:
        "tp":
            return _get_tp_command_autocomplete_entries(argument_body)
        "gamemode", "gm":
            return _get_gamemode_command_autocomplete_entries(argument_body)
        "spawn":
            return _get_spawn_command_autocomplete_entries(argument_body)
        "spawnmenu", "mobs":
            entries.append(_make_command_autocomplete_entry("/spawnmenu", "/spawnmenu", "Open the mob spawn browser"))
        "host", "lan":
            entries.append(_make_command_autocomplete_entry(text, text, "Host on the current LAN port"))
        "join":
            entries.append(_make_command_autocomplete_entry(text, text, "Join `ip [port]`"))
        "avatar":
            entries.append(_make_command_autocomplete_entry(text, text, "Set your avatar id"))
    return entries


func _get_root_command_autocomplete_entries(query: String) -> Array:
    var commands: Array = [
        {"command": "/host", "hint": "Host a LAN session"},
        {"command": "/join", "hint": "Join `ip [port]`"},
        {"command": "/tp", "hint": "Teleport to a connected player"},
        {"command": "/gamemode", "hint": "Session-only creative or survival"},
        {"command": "/spawn", "hint": "Spawn a mob for testing"},
        {"command": "/spawnmenu", "hint": "Open the mob spawn browser"},
        {"command": "/spawnlist", "hint": "List spawnable mob ids"},
        {"command": "/avatar", "hint": "Set your avatar id"},
    ]
    var lowered_query: String = query.to_lower()
    var entries: Array = []
    for command_entry in commands:
        var command_text: String = str(command_entry.get("command", ""))
        if lowered_query != "" and not command_text.substr(1).to_lower().begins_with(lowered_query):
            continue
        entries.append(_make_command_autocomplete_entry(command_text, command_text, str(command_entry.get("hint", ""))))
    return entries


func _get_tp_command_autocomplete_entries(query: String) -> Array:
    var entries: Array = []
    for target in get_teleport_target_entries(query):
        var label: String = str(target.get("label", target.get("insert", "")))
        var hint: String = str(target.get("hint", "Teleport"))
        entries.append(_make_command_autocomplete_entry("/tp %s" % str(target.get("insert", "")), label, hint))
    if entries.is_empty():
        entries.append(_make_command_autocomplete_entry("/tp ", "/tp <player>", "Teleport to host or a connected player"))
    return entries


func _get_gamemode_command_autocomplete_entries(query: String) -> Array:
    var modes: Array = [
        {"insert": "/gamemode c", "display": "/gamemode c", "hint": "Session creative"},
        {"insert": "/gamemode s", "display": "/gamemode s", "hint": "Session survival"},
    ]
    var lowered_query: String = query.to_lower()
    var entries: Array = []
    for mode_entry in modes:
        var command_text: String = str(mode_entry.get("insert", ""))
        if lowered_query != "" and not command_text.to_lower().contains(lowered_query):
            continue
        entries.append(_make_command_autocomplete_entry(command_text, str(mode_entry.get("display", command_text)), str(mode_entry.get("hint", ""))))
    return entries


func _get_spawn_command_autocomplete_entries(query: String) -> Array:
    var entries: Array = []
    var lowered_query: String = _normalize_debug_spawn_id(query)
    for spawn_id in _get_debug_spawn_ids():
        var spawn_text: String = str(spawn_id)
        if lowered_query != "" and not spawn_text.contains(lowered_query):
            continue
        entries.append(_make_command_autocomplete_entry("/spawn %s" % spawn_text, "/spawn %s" % spawn_text, "Spawn mob"))
    if entries.is_empty():
        entries.append(_make_command_autocomplete_entry("/spawn ", "/spawn <mob_id>", "Use `/spawnlist` for ids"))
    return entries


func _make_command_autocomplete_entry(insert_text: String, display_text: String, hint_text: String = "") -> Dictionary:
    return {
        "insert": insert_text,
        "display": display_text,
        "hint": hint_text,
    }


func get_teleport_target_entries(query: String = "") -> Array:
    var lowered_query: String = query.strip_edges().to_lower()
    var entries: Array = []
    for peer_id in peer_states.keys():
        var int_peer_id: int = int(peer_id)
        if int_peer_id == multiplayer.get_unique_id():
            continue
        var state: Dictionary = peer_states[peer_id]
        if not bool(state.get("active", false)):
            continue
        var peer_name: String = str(state.get("name", "Peer %s" % int_peer_id))
        var alias: String = "host" if int_peer_id == 1 else "p%s" % int_peer_id
        var matches_query: bool = lowered_query == "" \
            or alias.to_lower().contains(lowered_query) \
            or str(int_peer_id) == lowered_query \
            or peer_name.to_lower().contains(lowered_query)
        if not matches_query:
            continue
        var same_instance: bool = str(state.get("dimension_instance_key", "")) == get_active_dimension_instance_key()
        entries.append({
            "insert": alias,
            "label": "%s (%s)" % [peer_name, alias],
            "hint": "Teleport %s" % ("now" if same_instance else "after resync"),
            "peer_id": int_peer_id,
        })
    entries.sort_custom(Callable(self, "_sort_peer_autocomplete_entries"))
    return entries


func _sort_peer_autocomplete_entries(a: Dictionary, b: Dictionary) -> bool:
    return int(a.get("peer_id", 0)) < int(b.get("peer_id", 0))


func _execute_gamemode_command(parts: PackedStringArray) -> void:
    if parts.size() < 2:
        status_message = "Usage: /gamemode <c|s>"
        _update_status_text()
        return

    var mode: String = str(parts[1]).strip_edges().to_lower()
    match mode:
        "c", "creative", "1":
            _set_session_creative_mode(true)
        "s", "survival", "0":
            _set_session_creative_mode(false)
        _:
            status_message = "Usage: /gamemode <c|s>"
            _update_status_text()


func _set_session_creative_mode(enabled: bool) -> void:
    if not _can_sample_player() or not is_instance_valid(Ref.main):
        status_message = "Creative mode is unavailable right now"
        _update_status_text()
        return

    Ref.main.creative = enabled
    Ref.player.invincible = enabled
    Ref.player.invincible_temporary = false
    if enabled:
        Ref.player.health = Ref.player.max_health
    else:
        Ref.player.flying = false

    if is_instance_valid(Ref.game_menu) and Ref.game_menu.has_method("update_inventory_screen") and Ref.game_menu.is_inventory_open():
        Ref.game_menu.update_inventory_screen(int(Ref.game_menu.inventory_screen))

    status_message = "Session gamemode: %s" % ("creative" if enabled else "survival")
    _update_status_text()


func _execute_spawn_command(parts: PackedStringArray) -> void:
    if parts.size() < 2:
        status_message = "Usage: /spawn <mob_id>"
        _update_status_text()
        return

    if not _can_sample_player():
        status_message = "Player not ready for spawning"
        _update_status_text()
        return

    var spawn_id: String = _normalize_debug_spawn_id(" ".join(parts.slice(1)).strip_edges())
    if spawn_id == "":
        status_message = "Usage: /spawn <mob_id>"
        _update_status_text()
        return

    var spawn_origin: Vector3 = Ref.player.global_position
    var look_direction: Vector3 = Ref.player.get_look_direction() if Ref.player.has_method("get_look_direction") else -Ref.player.global_basis.z

    if not _has_live_peer() or multiplayer.is_server():
        status_message = _spawn_debug_entity_from_id(spawn_id, spawn_origin, look_direction)
        _update_status_text()
        return

    request_debug_spawn.rpc_id(1, spawn_id, get_active_dimension_instance_key(), spawn_origin, look_direction)
    status_message = "Requested spawn: %s" % spawn_id
    _update_status_text()


func _execute_spawnlist_command() -> void:
    var ids: PackedStringArray = _get_debug_spawn_ids()
    if ids.is_empty():
        status_message = "No spawn ids found"
        _update_status_text()
        return

    var preview_count: int = mini(ids.size(), 10)
    var preview: PackedStringArray = PackedStringArray()
    for i in range(preview_count):
        preview.append(ids[i])
    print("[lucid-blocks-coop-creative] spawn ids: %s" % ", ".join(ids))
    status_message = "Spawn ids (%d): %s%s" % [ids.size(), ", ".join(preview), " ..." if ids.size() > preview_count else ""]
    _update_status_text()


func _execute_spawnmenu_command(parts: PackedStringArray) -> void:
    var initial_query: String = " ".join(parts.slice(1)).strip_edges() if parts.size() > 1 else ""
    toggle_spawn_browser(true, initial_query)


func _normalize_debug_spawn_id(value: String) -> String:
    var normalized: String = value.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
    while normalized.contains("__"):
        normalized = normalized.replace("__", "_")
    return normalized.trim_prefix("_").trim_suffix("_")


func _get_debug_spawn_catalog() -> Dictionary:
    if not debug_spawn_catalog.is_empty():
        return debug_spawn_catalog

    var dir: DirAccess = DirAccess.open(DEBUG_SPAWN_RESOURCE_DIR)
    if dir != null:
        dir.list_dir_begin()
        var file_name: String = dir.get_next()
        while file_name != "":
            if not dir.current_is_dir() and file_name.ends_with(".tres"):
                _register_debug_spawn_resource(file_name)
            file_name = dir.get_next()
        dir.list_dir_end()

    if debug_spawn_catalog.is_empty():
        for spawn_id in DEBUG_SPAWN_FALLBACK_IDS:
            _register_debug_spawn_resource("%s_spawner.tres" % str(spawn_id))
    return debug_spawn_catalog


func _register_debug_spawn_resource(file_name: String) -> void:
    var basename: String = file_name.trim_suffix(".tres")
    if basename.ends_with("_spawner"):
        basename = basename.substr(0, basename.length() - 8)
    elif basename.ends_with("_capsule"):
        basename = basename.substr(0, basename.length() - 8)
    var primary_id: String = _normalize_debug_spawn_id(basename)
    if primary_id == "" or debug_spawn_catalog.has(primary_id):
        return
    var resource_path: String = "%s/%s" % [DEBUG_SPAWN_RESOURCE_DIR, file_name]
    var resource = load(resource_path)
    if primary_id != "" and resource is Spawner and str(resource.entity_path) != "":
        debug_spawn_catalog[primary_id] = {
            "resource_path": resource_path,
            "scene_path": str(resource.entity_path),
        }


func _get_debug_spawn_ids() -> PackedStringArray:
    var ids: PackedStringArray = PackedStringArray(_get_debug_spawn_catalog().keys())
    ids.sort()
    return ids


func _resolve_debug_spawn_entry(query: String) -> Dictionary:
    var catalog: Dictionary = _get_debug_spawn_catalog()
    if catalog.has(query):
        return catalog[query]

    var matches: Array[String] = []
    for spawn_id in catalog.keys():
        var id_text: String = str(spawn_id)
        if id_text.contains(query):
            matches.append(id_text)
    matches.sort()
    if matches.size() == 1:
        return catalog[matches[0]]
    return {}


func _spawn_debug_entity_from_id(spawn_id: String, spawn_origin: Vector3, look_direction: Vector3) -> String:
    var entry: Dictionary = _resolve_debug_spawn_entry(spawn_id)
    if entry.is_empty():
        return "Unknown spawn id: %s" % spawn_id

    var scene = load(str(entry.get("scene_path", "")))
    if not (scene is PackedScene):
        return "Spawn scene missing for %s" % spawn_id

    var entity = scene.instantiate()
    if not (entity is Entity):
        if entity != null:
            entity.queue_free()
        return "Spawn scene is not an entity: %s" % spawn_id

    var spawn_direction: Vector3 = look_direction
    if spawn_direction.length_squared() <= 0.0001:
        spawn_direction = Vector3.FORWARD
    spawn_direction = spawn_direction.normalized()
    if not entity.spawn_in_water:
        spawn_direction.y = 0.0
        if spawn_direction.length_squared() <= 0.0001:
            spawn_direction = Vector3.FORWARD
        spawn_direction = spawn_direction.normalized()

    var spawn_position: Vector3 = spawn_origin + Vector3(0, 1.25, 0) + spawn_direction * DEBUG_SPAWN_DISTANCE
    if is_instance_valid(Ref.world) and Ref.world.is_position_loaded(spawn_position):
        var attempts: int = 0
        while attempts < 10 and Ref.world.get_block_type_at(spawn_position.floor()).id != 0:
            spawn_position.y += 1.0
            attempts += 1

    entity.global_position = spawn_position
    entity.set_meta("coop_runtime_spawned", true)
    get_tree().get_root().add_child(entity)
    if entity.has_method("allow_swarm"):
        entity.allow_swarm()
    if multiplayer.is_server():
        _assign_sync_uuid(entity)
    return "Spawned %s" % spawn_id


func _execute_tp_command(parts: PackedStringArray) -> void:
    if parts.size() < 2:
        status_message = "Usage: /tp host or /tp <peer>"
        _update_status_text()
        return

    var query: String = " ".join(parts.slice(1)).strip_edges()
    var target_peer_id: int = -1
    var target_state: Dictionary = {}

    for peer_id in peer_states.keys():
        var int_peer_id: int = int(peer_id)
        if int_peer_id == multiplayer.get_unique_id():
            continue

        var state: Dictionary = peer_states[peer_id]
        var peer_name: String = str(state.get("name", "Peer %s" % int_peer_id))
        if query.to_lower() == "host" and int_peer_id == 1:
            target_peer_id = int_peer_id
            target_state = state
            break
        if query.to_lower() == ("p%s" % int_peer_id).to_lower() or query == str(int_peer_id) or peer_name.to_lower() == query.to_lower() or peer_name.to_lower().contains(query.to_lower()):
            target_peer_id = int_peer_id
            target_state = state
            break

    if target_peer_id == -1:
        status_message = "Peer not found: %s" % query
        _update_status_text()
        return

    if str(target_state.get("dimension_instance_key", "")) != get_active_dimension_instance_key():
        request_host_world_snapshot.rpc_id(1)
        status_message = "Resyncing to host world"
        _update_status_text()
        return

    _teleport_local_player_near(target_state.get("position", Ref.player.global_position))
    status_message = "Teleported to %s" % str(target_state.get("name", "peer %s" % target_peer_id))
    _update_status_text()


func _execute_visit_command(parts: PackedStringArray) -> void:
    if parts.size() < 2:
        status_message = "Usage: /visit <peer>"
        _update_status_text()
        return

    var target_state: Dictionary = _find_peer_state_by_query(" ".join(parts.slice(1)).strip_edges())
    if target_state.is_empty():
        status_message = "Peer not found"
        _update_status_text()
        return

    var target_player_key: String = str(target_state.get("player_key", "")).strip_edges()
    if target_player_key == "":
        status_message = "That player has no pocket id yet"
        _update_status_text()
        return

    open_dimension_instance(int(LucidBlocksWorld.Dimension.POCKET), target_player_key)


func _find_peer_state_by_query(query: String) -> Dictionary:
    var lowered_query: String = query.to_lower()
    for peer_id in peer_states.keys():
        var int_peer_id: int = int(peer_id)
        var state: Dictionary = peer_states[peer_id]
        var peer_name: String = str(state.get("name", "Peer %s" % int_peer_id))
        if lowered_query == "host" and int_peer_id == 1:
            return state
        if lowered_query == ("p%s" % int_peer_id).to_lower() or lowered_query == str(int_peer_id) or peer_name.to_lower() == lowered_query or peer_name.to_lower().contains(lowered_query):
            return state
    return {}


func _is_client_gameplay_locked() -> bool:
    return not multiplayer.is_server() and (reconnect_pending or client_restore_in_progress or receiving_host_world or not guest_persistent_ready or is_local_player_fake_dead() or is_local_player_downed())


func sync_local_block_place(block_position: Vector3i, block_id: int, inventory, inventory_index: int) -> bool:
    if not _has_live_peer():
        return false

    if multiplayer.is_server():
        _apply_network_place(block_position, block_id)
        if inventory != null:
            inventory.change_amount(inventory_index, -1)
        sync_place_block.rpc(block_position, block_id)
        return true

    if _is_local_world_authority():
        return false
    if _is_client_gameplay_locked():
        return false

    _apply_network_place(block_position, block_id)
    if inventory != null:
        inventory.change_amount(inventory_index, -1)
    request_place_block.rpc_id(1, block_position, block_id)
    return true


func sync_local_block_break(break_behavior, block_position: Vector3i) -> bool:
    if not _has_live_peer():
        return false
    if break_behavior == null or break_behavior.entity != Ref.player:
        return false
    if _is_local_world_authority():
        return false
    if multiplayer.is_server():
        return false
    if _is_client_gameplay_locked():
        return false

    var broken_block = break_behavior.block
    if broken_block == null and is_instance_valid(Ref.world) and Ref.world.is_position_loaded(block_position):
        broken_block = Ref.world.get_block_type_at(block_position)
    _predict_client_break_drops_for_block(
        broken_block,
        block_position,
        bool(break_behavior.pickaxe),
        bool(break_behavior.axe),
        bool(break_behavior.shovel),
        bool(break_behavior.meat),
        bool(break_behavior.plant)
    )
    _apply_client_break_feedback(break_behavior, block_position)
    _apply_network_break(block_position)
    request_break_block.rpc_id(
        1,
        block_position,
        bool(break_behavior.pickaxe),
        bool(break_behavior.axe),
        bool(break_behavior.shovel),
        bool(break_behavior.meat),
        bool(break_behavior.plant)
    )
    return true


func broadcast_host_block_break(block_position: Vector3i) -> void:
    if not _has_live_peer() or not multiplayer.is_server():
        return
    sync_break_block.rpc(block_position)


func broadcast_host_world_changes(block_changes: Array, fire_changes: Array) -> void:
    if not _has_live_peer() or not multiplayer.is_server():
        return
    if block_changes.is_empty() and fire_changes.is_empty():
        return

    sync_world_changes.rpc(get_active_dimension_instance_key(), block_changes, fire_changes)


func sync_host_attack_on_remote_player(attacker: Entity, target, damage_position: Vector3, damage: int, knockback_strength: float, fly_strength: float, fire_aspect: bool) -> bool:
    if not multiplayer.is_server() or not _has_live_peer() or not is_remote_player_proxy(target):
        return false

    var peer_id: int = get_remote_player_proxy_peer_id(target)
    if peer_id <= 1:
        return false

    receive_remote_player_attack.rpc_id(
        peer_id,
        _get_sync_uuid(attacker) if is_instance_valid(attacker) else "",
        attacker.global_position if is_instance_valid(attacker) else Vector3.ZERO,
        _get_entity_total_velocity(attacker) if is_instance_valid(attacker) else Vector3.ZERO,
        damage_position,
        maxi(1, damage),
        knockback_strength,
        fly_strength,
        fire_aspect
    )
    return true


func sync_local_drop_item(item_state, spawn_position: Vector3, launch_velocity: Vector3) -> bool:
    if not _has_live_peer() or multiplayer.is_server() or item_state == null:
        return false
    if _is_local_world_authority():
        return false
    if _is_client_gameplay_locked():
        return false

    _spawn_client_predicted_drop(item_state, spawn_position, launch_velocity, true, true)
    request_drop_item.rpc_id(1, _serialize_item_state(item_state), spawn_position, launch_velocity)
    return true


func sync_local_pickup_item(dropped_item) -> bool:
    if not _has_live_peer() or multiplayer.is_server() or dropped_item == null:
        return false
    if _is_local_world_authority():
        return false
    if _is_client_gameplay_locked():
        return false

    if is_instance_valid(dropped_item) and not dropped_item.can_collect:
        return true

    var item_uuid: String = _get_sync_uuid(dropped_item)
    if item_uuid == "":
        return bool(dropped_item.get_meta("coop_predicted_drop", false))

    var item_state = dropped_item.item.duplicate() if dropped_item.item != null else null

    if is_instance_valid(dropped_item) and dropped_item.can_collect:
        dropped_item.set_meta("coop_pickup_pending_request", true)
        synced_dropped_items.erase(item_uuid)
        client_collected_drop_uuids[item_uuid] = Time.get_ticks_msec()
        dropped_item.collect()

    if item_state != null:
        _queue_pending_pickup_receipt(item_state)
        var pickup_behavior = Ref.player.get_node_or_null("%PickUpItems")
        if pickup_behavior != null:
            pickup_behavior.accept_item(item_state, true)

    request_pickup_drop.rpc_id(1, item_uuid)
    return true


func sync_local_water_cells(changes: Array) -> bool:
    if not _has_live_peer() or multiplayer.is_server() or _is_local_world_authority() or changes.is_empty():
        return false
    if _is_client_gameplay_locked():
        return false
    request_water_cells.rpc_id(1, changes)
    return true


func sync_local_fire_cell(block_position: Vector3i, fire_level: int) -> bool:
    if not _has_live_peer() or multiplayer.is_server() or _is_local_world_authority():
        return false
    if _is_client_gameplay_locked():
        return false
    request_fire_cell.rpc_id(1, block_position, fire_level)
    return true


func sync_local_foliage_break(block_position: Vector3i) -> bool:
    if not _has_live_peer() or multiplayer.is_server() or _is_local_world_authority():
        return false
    if _is_client_gameplay_locked():
        return false

    var block: Block = Ref.world.get_block_type_at(block_position)
    _apply_network_break(block_position)
    if block != null and block.foliage and block.can_drop:
        var new_state := ItemState.new()
        new_state.initialize(block)
        new_state.count = 1
        _spawn_client_predicted_drop(new_state, Vector3(block_position))

    request_foliage_break.rpc_id(1, block_position)
    return true


func _cleanup_client_prediction_state() -> void:
    if multiplayer.is_server():
        return

    var now_ms: int = Time.get_ticks_msec()

    for uuid in client_collected_drop_uuids.keys().duplicate():
        if now_ms - int(client_collected_drop_uuids[uuid]) > 10000:
            client_collected_drop_uuids.erase(uuid)
    for child in _get_live_tracked_drops():
        if not (child is DroppedItem):
            continue
        if not bool(child.get_meta("coop_predicted_drop", false)):
            continue
        var created_ms: int = int(child.get_meta("coop_predicted_created_ms", 0))
        if created_ms > 0 and now_ms - created_ms > int(CLIENT_PREDICTED_DROP_LIFETIME * 1000.0):
            child.call_deferred("queue_free")

    if pending_pickup_receipts.is_empty():
        return

    var live_receipts: Array = []
    for receipt in pending_pickup_receipts:
        if not (receipt is Dictionary):
            continue
        var created_ms: int = int(receipt.get("created_ms", 0))
        if created_ms <= 0 or now_ms - created_ms <= int(CLIENT_PENDING_PICKUP_LIFETIME * 1000.0):
            live_receipts.append(receipt)
    pending_pickup_receipts = live_receipts


func _queue_pending_pickup_receipt(item_state) -> void:
    var signature: String = _item_state_signature(item_state)
    if signature == "":
        return
    pending_pickup_receipts.append({
        "signature": signature,
        "created_ms": Time.get_ticks_msec(),
    })


func _consume_pending_pickup_receipt(item_state) -> bool:
    var signature: String = _item_state_signature(item_state)
    if signature == "":
        return false

    for index in range(pending_pickup_receipts.size()):
        var receipt: Dictionary = pending_pickup_receipts[index]
        if str(receipt.get("signature", "")) != signature:
            continue
        pending_pickup_receipts.remove_at(index)
        return true
    return false


func _item_data_signature(item_data: PackedInt32Array) -> String:
    if item_data.is_empty():
        return ""

    var signature: String = ""
    for index in range(item_data.size()):
        if index > 0:
            signature += ":"
        signature += str(int(item_data[index]))
    return signature


func _item_state_signature(item_state) -> String:
    return _item_data_signature(_serialize_item_state(item_state))


func _mark_client_predicted_drop(dropped_item, item_state) -> void:
    if dropped_item == null:
        return

    dropped_item.set_meta("coop_predicted_drop", true)
    dropped_item.set_meta("coop_predicted_created_ms", Time.get_ticks_msec())
    dropped_item.set_meta("coop_predicted_item_signature", _item_state_signature(item_state))
    dropped_item.set_meta("coop_drop_snapshot_initialized", true)
    dropped_item.set_meta("coop_pickup_pending_request", false)
    if dropped_item is DroppedItem:
        dropped_item.can_collect = false
        dropped_item.can_merge = false
        dropped_item.disabled = false
        dropped_item.is_collect_delayed = false
        dropped_item.is_merge_delayed = false
        dropped_item.set_physics_process(true)


func _spawn_client_predicted_drop(item_state, spawn_position: Vector3, launch_velocity: Vector3 = Vector3.ZERO, use_launch_velocity: bool = false, delay_collect: bool = false):
    if item_state == null:
        return null

    var scene = load(DROPPED_ITEM_SCENE_PATH)
    if not (scene is PackedScene):
        return null

    var dropped_item = scene.instantiate()
    if dropped_item == null:
        return null

    get_tree().get_root().add_child(dropped_item)
    if delay_collect and dropped_item.has_method("delay_collect"):
        dropped_item.delay_collect()
    dropped_item.global_position = spawn_position
    dropped_item.initialize(item_state)
    if use_launch_velocity:
        dropped_item.global_position = spawn_position
        dropped_item.velocity = launch_velocity
    _mark_client_predicted_drop(dropped_item, item_state)
    return dropped_item


func _predict_client_break_drops_for_block(block, block_position: Vector3i, pickaxe: bool, axe: bool, shovel: bool, meat: bool, plant: bool) -> void:
    if block == null:
        return
    if block.pickaxe_required and not pickaxe:
        return
    if block.axe_required and not axe:
        return
    if block.drop_loot != null:
        return

    var to_drop: Array[ItemState] = []
    if block.drop_item == null:
        if not block.can_drop:
            return
        var default_state := ItemState.new()
        default_state.initialize(block)
        default_state.count = 1
        to_drop.append(default_state)
    else:
        var explicit_state := ItemState.new()
        explicit_state.initialize(block.drop_item)
        explicit_state.count = 1
        to_drop.append(explicit_state)

    for dropped_state in to_drop:
        _spawn_client_predicted_drop(dropped_state, Vector3(block_position))


func _find_matching_predicted_drop(item_state, drop_position: Vector3, match_distance: float = CLIENT_PREDICTED_DROP_MATCH_DISTANCE):
    var signature: String = _item_state_signature(item_state)
    if signature == "":
        return null

    var nearest = null
    var nearest_distance_squared: float = match_distance * match_distance
    for child in _get_live_tracked_drops():
        if not (child is DroppedItem):
            continue
        if not bool(child.get_meta("coop_predicted_drop", false)):
            continue
        if str(child.get_meta("coop_predicted_item_signature", "")) != signature:
            continue

        var distance_squared: float = child.global_position.distance_squared_to(drop_position)
        if distance_squared > nearest_distance_squared:
            continue
        nearest = child
        nearest_distance_squared = distance_squared
    return nearest


func _is_client_drop_within_pickup_radius(dropped_item) -> bool:
    if not _can_sample_player() or dropped_item == null or not is_instance_valid(dropped_item):
        return false
    if Ref.player.dead or Ref.player.disabled:
        return false
    return dropped_item.global_position.distance_squared_to(Ref.player.global_position) <= CLIENT_AUTO_PICKUP_RADIUS * CLIENT_AUTO_PICKUP_RADIUS


func _attempt_client_auto_pickup_drop(dropped_item) -> void:
    if multiplayer.is_server() or dropped_item == null or not is_instance_valid(dropped_item):
        return
    if not dropped_item.can_collect:
        return
    if bool(dropped_item.get_meta("coop_pickup_pending_request", false)):
        return
    if not _is_client_drop_within_pickup_radius(dropped_item):
        return

    sync_local_pickup_item(dropped_item)


func _find_client_drop_merge_target(dropped_item):
    if dropped_item == null or not is_instance_valid(dropped_item) or dropped_item.item == null:
        return null

    var nearest = null
    var nearest_distance_squared: float = CLIENT_DROP_MERGE_ANIMATION_DISTANCE * CLIENT_DROP_MERGE_ANIMATION_DISTANCE
    for other in _get_live_tracked_drops():
        if other == dropped_item or not (other is DroppedItem) or not is_instance_valid(other):
            continue
        if other.item == null or other.state == DroppedItem.COLLECTED:
            continue
        if other.item.id != dropped_item.item.id:
            continue
        var distance_squared: float = dropped_item.global_position.distance_squared_to(other.global_position)
        if distance_squared > nearest_distance_squared:
            continue
        nearest = other
        nearest_distance_squared = distance_squared
    return nearest


func _animate_client_drop_merge_removal(dropped_item) -> void:
    if dropped_item == null or not is_instance_valid(dropped_item):
        return
    var merge_target = _find_client_drop_merge_target(dropped_item)
    if merge_target == null or not is_instance_valid(merge_target):
        dropped_item.queue_free()
        return

    dropped_item.set_meta("coop_merge_cleanup_pending", true)
    if dropped_item is DroppedItem:
        dropped_item.disabled = true
        dropped_item.can_collect = false
        dropped_item.can_merge = false
        dropped_item.toggle_collision(false)
    var tween: Tween = get_tree().create_tween()
    tween.tween_property(dropped_item, "global_position", merge_target.global_position, CLIENT_DROP_MERGE_ANIMATION_TIME)
    await tween.finished
    if is_instance_valid(dropped_item):
        dropped_item.queue_free()


func _should_keep_client_entity_area_active(area: Area3D) -> bool:
    return area != null and str(area.name) == "InteractArea3D"


func _can_share_loaded_world() -> bool:
    return is_instance_valid(Ref.main) and is_instance_valid(Ref.world) and Ref.main.loaded and Ref.world.load_enabled and Ref.save_file_manager.loaded_file_register != null and Ref.save_file_manager.loaded_file != null


func _mark_host_contact() -> void:
    last_host_contact_time = Time.get_ticks_msec()


func _has_host_timed_out() -> bool:
    if multiplayer.is_server() or not _has_live_peer() or local_quit_in_progress:
        return false
    if last_host_contact_time <= 0:
        return false
    var timeout_seconds: float = HOST_TIMEOUT_SECONDS * (3.0 if (receiving_host_world or client_restore_in_progress) else 1.0)
    return (Time.get_ticks_msec() - last_host_contact_time) > int(timeout_seconds * 1000.0)


func _autosave_host_world_if_needed() -> void:
    if autosave_in_progress or local_fake_death_pending or handling_host_respawn or host_respawning or not multiplayer.is_server() or not _can_share_loaded_world():
        return
    _run_host_autosave.call_deferred()


func _flush_pending_remote_world_changes() -> void:
    if multiplayer.is_server() or not _has_live_peer() or not _can_sample_player() or not is_instance_valid(Ref.world):
        return

    for block_position in pending_remote_block_changes.keys().duplicate():
        if not Ref.world.is_position_loaded(block_position):
            continue
        var block_id: int = int(pending_remote_block_changes[block_position])
        pending_remote_block_changes.erase(block_position)
        if block_id <= 0:
            _apply_loaded_network_break(block_position)
        else:
            _apply_loaded_network_place(block_position, block_id)

    for block_position in pending_remote_water_changes.keys().duplicate():
        if not Ref.world.is_position_loaded(block_position):
            continue
        var water_level: int = int(pending_remote_water_changes[block_position])
        pending_remote_water_changes.erase(block_position)
        Ref.world.place_water_at(block_position, water_level)

    for block_position in pending_remote_fire_changes.keys().duplicate():
        if not Ref.world.is_position_loaded(block_position):
            continue
        var fire_level: int = int(pending_remote_fire_changes[block_position])
        pending_remote_fire_changes.erase(block_position)
        Ref.world.place_fire_at(block_position, fire_level)


func _run_host_autosave() -> void:
    if autosave_in_progress or local_fake_death_pending or handling_host_respawn or host_respawning or not multiplayer.is_server() or not _can_share_loaded_world():
        return

    autosave_in_progress = true
    await Ref.save_file_manager.save_file(true)
    autosave_in_progress = false


func _capture_local_state() -> Dictionary:
    var state: Dictionary = {
        "active": false,
        "downed": false,
        "dimension": -1,
        "position": Vector3.ZERO,
        "yaw": 0.0,
        "pitch": 0.0,
        "crouching": false,
        "grounded": true,
        "move_speed": 0.0,
        "held_item_id": -1,
        "under_water": false,
        "action_state": 0,
        "name": _get_local_player_name(),
        "player_key": _get_local_player_key(),
        "avatar_id": _normalize_avatar_id(str(config.get("avatar_id", DEFAULT_AVATAR_ID))),
        "skin_color": _get_local_skin_color(),
        "pocket_owner_key": "",
        "dimension_instance_key": "",
        "breaking": false,
        "break_position": Vector3i.ZERO,
        "break_block_id": 0,
        "break_progress": 0.0,
    }

    if not _can_sample_player():
        return state

    var rotation_pivot: Node3D = _get_rotation_pivot()
    var camera: Camera3D = Ref.player.get_node_or_null("%Camera3D") as Camera3D
    state["downed"] = local_downed
    if multiplayer.is_server():
        state["active"] = not (local_fake_death_pending or host_respawning)
    else:
        state["active"] = guest_persistent_ready and not receiving_host_world and not is_local_player_fake_dead()
    if local_downed:
        state["active"] = true
    state["dimension"] = int(Ref.world.current_dimension)
    state["pocket_owner_key"] = get_active_pocket_owner_key()
    state["dimension_instance_key"] = get_active_dimension_instance_key()
    state["position"] = Ref.player.global_position
    state["yaw"] = rotation_pivot.rotation.y if rotation_pivot != null else Ref.player.rotation.y
    state["pitch"] = camera.rotation.x if camera != null else 0.0
    state["crouching"] = Ref.player.is_crouching
    state["grounded"] = not Ref.player.in_air
    state["move_speed"] = Vector3(Ref.player.velocity.x, 0.0, Ref.player.velocity.z).length()
    state["under_water"] = Ref.player.under_water
    var held_item_state = Ref.player.held_item_inventory.items[Ref.player.held_item_index]
    state["held_item_id"] = held_item_state.id if held_item_state != null else -1
    state["action_state"] = _get_local_action_state()
    state.merge(_get_local_break_state(), true)
    return state


func _capture_local_state_for_send() -> Dictionary:
    var state: Dictionary = _capture_local_state()
    local_state_sequence += 1
    state["sequence"] = local_state_sequence
    return state


func _normalize_avatar_id(raw_avatar_id: String) -> String:
    var normalized: String = raw_avatar_id.strip_edges().to_lower()
    return normalized if normalized != "" else DEFAULT_AVATAR_ID


func _get_local_player_name() -> String:
    var steam_name: String = str(Steamworks.get_username())
    if steam_name.strip_edges() != "":
        return steam_name
    return "Peer %s" % multiplayer.get_unique_id()


func _get_local_player_key() -> String:
    if int(Steamworks.steam_id) > 0:
        return "steam_%s" % int(Steamworks.steam_id)

    var fallback_name: String = _slugify_string(_get_local_player_name())
    if fallback_name != "":
        return "name_%s" % fallback_name
    return "peer_%s" % multiplayer.get_unique_id()


func _slugify_string(raw_text: String) -> String:
    var normalized: String = raw_text.strip_edges().to_lower()
    var output: PackedStringArray = []
    for character in normalized:
        var unicode_value: int = character.unicode_at(0)
        var is_digit: bool = unicode_value >= 48 and unicode_value <= 57
        var is_lower: bool = unicode_value >= 97 and unicode_value <= 122
        if is_digit or is_lower:
            output.append(character)
        elif output.is_empty() or output[-1] != "_":
            output.append("_")

    var slug: String = "".join(output).strip_edges()
    return slug.trim_prefix("_").trim_suffix("_")


func _get_loaded_register_pocket_owner_key() -> String:
    if Ref.save_file_manager == null or Ref.save_file_manager.loaded_file_register == null:
        return ""
    return str(Ref.save_file_manager.loaded_file_register.get_data("pocket_owner_key", "")).strip_edges()


func get_active_pocket_owner_key() -> String:
    if not _can_sample_player() or int(Ref.world.current_dimension) != int(LucidBlocksWorld.Dimension.POCKET):
        return ""

    var owner_key: String = _get_loaded_register_pocket_owner_key()
    if owner_key != "":
        return owner_key
    return _get_local_player_key() if _has_live_peer() else ""


func get_dimension_instance_key(dimension: int, pocket_owner_key: String = "") -> String:
    if dimension == int(LucidBlocksWorld.Dimension.POCKET):
        var owner_key: String = pocket_owner_key.strip_edges()
        return "pocket:%s" % (owner_key if owner_key != "" else "legacy")
    return "dimension:%s" % dimension


func _resolve_dimension_namespace(dimension: int, pocket_owner_key: String = "") -> String:
    var dimension_namespace: String = SaveFile.DIMENSION_MAP.get(dimension, "unknown")
    if dimension == int(LucidBlocksWorld.Dimension.POCKET) and pocket_owner_key.strip_edges() != "":
        dimension_namespace = "%s__%s" % [dimension_namespace, pocket_owner_key.strip_edges()]
    return dimension_namespace


func get_active_dimension_instance_key() -> String:
    if not _can_sample_player():
        return ""
    return get_dimension_instance_key(int(Ref.world.current_dimension), get_active_pocket_owner_key())


func _get_host_dimension_instance_key() -> String:
    if peer_states.has(1):
        return str(peer_states[1].get("dimension_instance_key", ""))
    return ""


func _is_local_world_authority() -> bool:
    if multiplayer.is_server():
        return true
    if reconnect_pending or client_restore_in_progress:
        return false
    return not _has_live_peer()


func has_connected_remote_peers() -> bool:
    if multiplayer.multiplayer_peer == null:
        return false
    if multiplayer.is_server():
        return multiplayer.multiplayer_peer.get_peers().size() > 0
    return _has_live_peer()


func _refresh_world_authority_mode() -> void:
    if not _can_sample_player():
        return
    var has_authority: bool = _is_local_world_authority()
    Ref.world.simulate_enabled = has_authority

    if not multiplayer.is_server() and is_instance_valid(Ref.entity_spawner) and has_authority != last_local_world_authority:
        if has_authority:
            Ref.entity_spawner.start_spawning()
        else:
            Ref.entity_spawner.stop_spawning()
    last_local_world_authority = has_authority


func _set_host_runtime_process_mode(node: Node, active: bool) -> void:
    if node == null or not is_instance_valid(node):
        return

    if active:
        if not node.has_meta("coop_host_original_process_mode"):
            node.set_meta("coop_host_original_process_mode", int(node.process_mode))
        node.process_mode = Node.PROCESS_MODE_ALWAYS
    elif node.has_meta("coop_host_original_process_mode"):
        node.process_mode = int(node.get_meta("coop_host_original_process_mode", int(Node.PROCESS_MODE_INHERIT)))
        node.remove_meta("coop_host_original_process_mode")

    for child in node.get_children():
        _set_host_runtime_process_mode(child, active)


func _set_host_entity_activity_override(entity: Entity, active: bool) -> void:
    if entity == null or not is_instance_valid(entity) or not entity.is_inside_tree():
        return

    if _object_has_property(entity, "disabled_by_visibility"):
        if active:
            if not entity.has_meta("coop_host_original_disabled_by_visibility"):
                entity.set_meta("coop_host_original_disabled_by_visibility", bool(entity.get("disabled_by_visibility")))
            entity.set("disabled_by_visibility", false)
        elif entity.has_meta("coop_host_original_disabled_by_visibility"):
            entity.set("disabled_by_visibility", bool(entity.get_meta("coop_host_original_disabled_by_visibility", true)))
            entity.remove_meta("coop_host_original_disabled_by_visibility")

    _set_host_runtime_process_mode(entity, active)

    if active:
        entity.set_process(true)
        entity.set_physics_process(true)
    elif entity.has_method("distance_process_check"):
        entity.call("distance_process_check")

    if entity.has_method("_refresh_visibility_enabler_target"):
        entity.call("_refresh_visibility_enabler_target")

    var visible_enabler: VisibleOnScreenEnabler3D = entity.get_node_or_null("%VisibleOnScreenEnabler3D") as VisibleOnScreenEnabler3D
    if visible_enabler != null:
        if active:
            if not visible_enabler.has_meta("coop_host_original_enable_node_path"):
                visible_enabler.set_meta("coop_host_original_enable_node_path", str(visible_enabler.enable_node_path))
            if not visible_enabler.has_meta("coop_host_original_process_mode"):
                visible_enabler.set_meta("coop_host_original_process_mode", int(visible_enabler.process_mode))
            visible_enabler.enable_node_path = ""
            visible_enabler.process_mode = Node.PROCESS_MODE_DISABLED
        else:
            visible_enabler.enable_node_path = str(visible_enabler.get_meta("coop_host_original_enable_node_path", ".."))
            visible_enabler.process_mode = int(visible_enabler.get_meta("coop_host_original_process_mode", int(Node.PROCESS_MODE_INHERIT)))
            visible_enabler.remove_meta("coop_host_original_enable_node_path")
            visible_enabler.remove_meta("coop_host_original_process_mode")

    var distance_timer: Timer = entity.get_node_or_null("%DistanceCheckTimer") as Timer
    if distance_timer != null:
        if active:
            if not distance_timer.has_meta("coop_host_original_process_mode"):
                distance_timer.set_meta("coop_host_original_process_mode", int(distance_timer.process_mode))
            distance_timer.process_mode = Node.PROCESS_MODE_ALWAYS
            if distance_timer.is_stopped():
                distance_timer.start()
        elif distance_timer.has_meta("coop_host_original_process_mode"):
            distance_timer.process_mode = int(distance_timer.get_meta("coop_host_original_process_mode", int(Node.PROCESS_MODE_INHERIT)))
            distance_timer.remove_meta("coop_host_original_process_mode")


func _clear_host_entity_activity_override() -> void:
    if not host_entity_activity_override_active:
        return
    for child in _get_live_tracked_entities():
        if not (child is Entity) or child is Player or is_remote_player_proxy(child):
            continue
        _set_host_entity_activity_override(child as Entity, false)
    host_entity_activity_override_active = false


func _refresh_host_entity_activity_override(delta: float) -> void:
    if not multiplayer.is_server() or not _has_live_peer():
        host_entity_activity_refresh_timer = 0.0
        _clear_host_entity_activity_override()
        return

    host_entity_activity_refresh_timer += delta
    if host_entity_activity_refresh_timer < 0.2:
        return
    host_entity_activity_refresh_timer = 0.0

    for child in _get_live_tracked_entities():
        if not (child is Entity) or child is Player or is_remote_player_proxy(child):
            continue
        var entity := child as Entity
        if entity == null or not is_instance_valid(entity) or not entity.is_inside_tree():
            continue
        _set_host_entity_activity_override(entity, true)
    host_entity_activity_override_active = true


func _get_same_instance_session_positions() -> Array:
    var positions: Array = []
    if not _can_sample_player():
        return positions

    if _is_local_session_player_active():
        positions.append(Ref.player.global_position)
    if not _has_live_peer():
        return positions

    var local_peer_id: int = multiplayer.get_unique_id()
    var active_instance_key: String = get_active_dimension_instance_key()
    for peer_id in peer_states.keys():
        if int(peer_id) == local_peer_id:
            continue
        var state: Dictionary = peer_states[peer_id]
        if not bool(state.get("active", false)):
            continue
        if str(state.get("dimension_instance_key", "")) != active_instance_key:
            continue
        positions.append(state.get("position", Ref.player.global_position))

    return positions


func get_same_instance_session_positions() -> Array:
    return _get_same_instance_session_positions().duplicate()


func get_same_instance_session_player_count() -> int:
    return _get_same_instance_session_positions().size()


func get_same_instance_base_load_radius(default_radius: float = 0.0) -> float:
    var base_radius: float = default_radius
    if Ref.save_file_manager != null and Ref.save_file_manager.settings_file != null:
        base_radius = maxf(base_radius, float(Ref.save_file_manager.settings_file.get_data("render_distance", 80.0)))
    if multiplayer.is_server() and session_load_radius_applied and session_previous_instance_radius > 0:
        base_radius = float(session_previous_instance_radius)
    return maxf(base_radius, 16.0)


func get_same_instance_activity_radius(default_radius: float = 0.0) -> float:
    var activity_radius: float = maxf(get_same_instance_base_load_radius(default_radius) - 16.0, 16.0)
    if not multiplayer.is_server() or not _has_live_peer() or not _can_sample_player() or not is_instance_valid(Ref.world):
        return activity_radius

    var positions: Array = _get_same_instance_session_positions()
    if positions.size() <= 1:
        return activity_radius

    var load_center: Vector3 = get_world_load_center(Ref.player.global_position)
    var load_radius: float = maxf(
        float(Ref.world.instance_radius),
        float(get_world_load_radius_target(int(round(get_same_instance_base_load_radius(default_radius)))))
    )
    var farthest_player_distance: float = 0.0
    for position in positions:
        farthest_player_distance = maxf(farthest_player_distance, load_center.distance_to(position))

    var safe_activity_radius: float = maxf(16.0, load_radius - farthest_player_distance - 16.0)
    return minf(activity_radius, safe_activity_radius)


func get_nearest_session_player_distance(world_position: Vector3, fallback_distance: float = INF) -> float:
    var positions: Array = _get_same_instance_session_positions()
    if positions.is_empty():
        return fallback_distance
    var nearest_distance: float = INF
    for position in positions:
        nearest_distance = minf(nearest_distance, world_position.distance_to(position))
    return nearest_distance


func get_nearest_session_player_position(world_position: Vector3, fallback_position: Vector3 = Vector3.ZERO) -> Vector3:
    var positions: Array = _get_same_instance_session_positions()
    if positions.is_empty():
        return fallback_position
    var nearest_position: Vector3 = positions[0]
    var nearest_distance_squared: float = world_position.distance_squared_to(nearest_position)
    for position in positions:
        var distance_squared: float = world_position.distance_squared_to(position)
        if distance_squared < nearest_distance_squared:
            nearest_distance_squared = distance_squared
            nearest_position = position
    return nearest_position


func _is_peer_state_same_instance(state: Dictionary, active_instance_key: String) -> bool:
    return bool(state.get("active", false)) and str(state.get("dimension_instance_key", "")) == active_instance_key


func _is_local_session_player_active() -> bool:
    return _can_sample_player() and not Ref.player.dead and (not Ref.player.disabled or is_local_player_downed()) and not is_local_player_fake_dead() and Ref.player.is_inside_tree()


func get_nearest_session_player_head_position(world_position: Vector3, fallback_position: Vector3 = Vector3.ZERO) -> Vector3:
    var nearest_head_position: Vector3 = fallback_position
    var nearest_distance_squared: float = INF

    if _is_local_session_player_active():
        var local_head: Vector3 = Ref.player.head.global_position if is_instance_valid(Ref.player.head) else Ref.player.global_position + Vector3(0, 1.45, 0)
        nearest_head_position = local_head
        nearest_distance_squared = world_position.distance_squared_to(Ref.player.global_position)

    if not _has_live_peer():
        return nearest_head_position

    var local_peer_id: int = multiplayer.get_unique_id()
    var active_instance_key: String = get_active_dimension_instance_key()
    for peer_id in peer_states.keys():
        var int_peer_id: int = int(peer_id)
        if int_peer_id == local_peer_id:
            continue
        var state: Dictionary = peer_states[peer_id]
        if not _is_peer_state_same_instance(state, active_instance_key):
            continue
        var peer_position: Vector3 = state.get("position", Vector3.ZERO)
        var distance_squared: float = world_position.distance_squared_to(peer_position)
        if distance_squared >= nearest_distance_squared:
            continue
        nearest_distance_squared = distance_squared
        nearest_head_position = peer_position + Vector3(0, 1.45 if not bool(state.get("crouching", false)) else 1.1, 0)

    return nearest_head_position


func is_position_near_same_instance_player(world_position: Vector3, radius: float) -> bool:
    return _is_near_any_session_position(world_position, _get_same_instance_session_positions(), radius)


func get_next_same_instance_spawn_anchor(default_position: Vector3) -> Vector3:
    var positions: Array = _get_same_instance_session_positions()
    if positions.is_empty():
        return default_position
    spawn_anchor_index = posmod(spawn_anchor_index, positions.size())
    var anchor: Vector3 = positions[spawn_anchor_index]
    spawn_anchor_index = (spawn_anchor_index + 1) % positions.size()
    return anchor


func get_nearest_session_player_entity(world_position: Vector3, fallback = null):
    var nearest = fallback
    var nearest_distance_squared: float = INF

    if _is_local_session_player_active():
        nearest = Ref.player
        nearest_distance_squared = world_position.distance_squared_to(Ref.player.global_position)

    if not _has_live_peer():
        return nearest

    var active_instance_key: String = get_active_dimension_instance_key()
    for peer_id in remote_player_proxies.keys():
        var proxy = remote_player_proxies[peer_id]
        if not is_instance_valid(proxy) or proxy.dead or not proxy.is_inside_tree():
            continue
        var state: Dictionary = peer_states.get(peer_id, {})
        if not _is_peer_state_same_instance(state, active_instance_key):
            continue
        var distance_squared: float = world_position.distance_squared_to(proxy.global_position)
        if distance_squared >= nearest_distance_squared:
            continue
        nearest = proxy
        nearest_distance_squared = distance_squared

    return nearest


func is_remote_player_proxy(node) -> bool:
    return is_instance_valid(node) and node.has_meta("coop_remote_player_proxy")


func get_remote_player_proxy_peer_id(node) -> int:
    if not is_remote_player_proxy(node):
        return -1
    return int(node.get_meta("coop_remote_player_proxy_peer_id", -1))


func get_remote_player_proxy(peer_id: int):
    if not remote_player_proxies.has(peer_id):
        return null
    var proxy = remote_player_proxies[peer_id]
    return proxy if is_instance_valid(proxy) else null


func is_client_synced_entity(node) -> bool:
    return false


func push_client_entity_authoritative_change(node) -> void:
    return


func pop_client_entity_authoritative_change(node) -> void:
    return


func is_client_entity_authoritative_change_active(node) -> bool:
    return false


func get_world_load_center(default_center: Vector3) -> Vector3:
    if not multiplayer.is_server() or not _has_live_peer():
        return default_center

    var positions: Array = _get_same_instance_session_positions()
    if positions.size() <= 1:
        return default_center

    var min_corner: Vector3 = positions[0]
    var max_corner: Vector3 = positions[0]
    for position in positions:
        min_corner = min_corner.min(position)
        max_corner = max_corner.max(position)

    return _snap_world_stream_position((min_corner + max_corner) * 0.5)


func _snap_world_stream_position(position: Vector3) -> Vector3:
    return Vector3(
        floor(position.x / 16.0) * 16.0 + 8.0,
        floor(position.y / 16.0) * 16.0 + 8.0,
        floor(position.z / 16.0) * 16.0 + 8.0
    )


func _is_near_any_session_position(world_position: Vector3, positions: Array, radius: float) -> bool:
    var radius_squared: float = radius * radius
    for position in positions:
        if world_position.distance_squared_to(position) <= radius_squared:
            return true
    return false


func get_world_load_radius_target(default_radius: int) -> int:
    var target_radius: int = maxi(default_radius, HOST_SESSION_MIN_LOAD_RADIUS)
    if not multiplayer.is_server() or not _has_live_peer():
        return mini(target_radius, HOST_SESSION_MAX_LOAD_RADIUS)

    var positions: Array = _get_same_instance_session_positions()
    if positions.size() <= 1:
        return target_radius

    var center: Vector3 = get_world_load_center(Ref.player.global_position)
    var farthest_distance: float = 0.0
    for position in positions:
        farthest_distance = maxf(farthest_distance, center.distance_to(position))

    var snapped_radius: int = int(ceil((farthest_distance + HOST_SESSION_EDGE_BUFFER) / float(HOST_SESSION_RADIUS_STEP))) * HOST_SESSION_RADIUS_STEP
    return mini(maxi(target_radius, snapped_radius), HOST_SESSION_MAX_LOAD_RADIUS)


func _refresh_session_load_radius() -> void:
    if not _can_sample_player() or not is_instance_valid(Ref.world):
        return

    if _has_live_peer() and multiplayer.is_server():
        if not session_load_radius_applied:
            session_previous_instance_radius = int(Ref.world.instance_radius)
            session_previous_buffer_instance_radius = int(Ref.world.buffer_instance_radius)
            session_load_radius_applied = true

        var target_radius: int = get_world_load_radius_target(session_previous_instance_radius)

        var target_buffer_radius: int = maxi(session_previous_buffer_instance_radius, target_radius + 256)

        if int(Ref.world.instance_radius) != target_radius:
            Ref.world.instance_radius = target_radius
            Ref.world.buffer_instance_radius = target_buffer_radius
            Ref.world.force_reload()
        elif int(Ref.world.buffer_instance_radius) != target_buffer_radius:
            Ref.world.buffer_instance_radius = target_buffer_radius
    elif session_load_radius_applied:
        if session_previous_instance_radius > 0 and int(Ref.world.instance_radius) != session_previous_instance_radius:
            Ref.world.instance_radius = session_previous_instance_radius
            Ref.world.buffer_instance_radius = session_previous_buffer_instance_radius if session_previous_buffer_instance_radius > 0 else Ref.world.buffer_instance_radius
            Ref.world.force_reload()
        elif session_previous_buffer_instance_radius > 0 and int(Ref.world.buffer_instance_radius) != session_previous_buffer_instance_radius:
            Ref.world.buffer_instance_radius = session_previous_buffer_instance_radius
        session_load_radius_applied = false
        session_previous_instance_radius = -1
        session_previous_buffer_instance_radius = -1


func _get_nearest_connected_peer_state() -> Dictionary:
    if not _has_live_peer() or not _can_sample_player():
        return {}
    var active_instance_key: String = get_active_dimension_instance_key()
    var nearest_state: Dictionary = {}
    var nearest_distance_squared: float = INF
    for peer_id in peer_states.keys():
        var int_peer_id: int = int(peer_id)
        if int_peer_id == multiplayer.get_unique_id():
            continue
        var state: Dictionary = peer_states[peer_id]
        if not _is_peer_state_same_instance(state, active_instance_key):
            continue
        var peer_position: Vector3 = state.get("position", Vector3.ZERO)
        var distance_squared: float = Ref.player.global_position.distance_squared_to(peer_position)
        if distance_squared < nearest_distance_squared:
            nearest_distance_squared = distance_squared
            nearest_state = state
    return nearest_state


func _enforce_shared_bubble_tether(delta: float) -> void:
    if not _has_live_peer() or not _can_sample_player():
        return
    if reconnect_pending or client_restore_in_progress or remote_host_respawning or is_local_player_fake_dead() or is_local_player_downed() or Ref.player.dead or Ref.player.disabled:
        return
    var nearest_state: Dictionary = _get_nearest_connected_peer_state()
    if nearest_state.is_empty():
        return

    var peer_position: Vector3 = nearest_state.get("position", Ref.player.global_position)
    var to_local: Vector3 = Ref.player.global_position - peer_position
    var distance: float = to_local.length()
    if distance <= SHARED_BUBBLE_SOFT_TETHER_DISTANCE:
        return

    var direction: Vector3 = to_local.normalized() if distance > 0.001 else Vector3.RIGHT
    if distance > SHARED_BUBBLE_HARD_TETHER_DISTANCE:
        Ref.player.global_position = peer_position + direction * SHARED_BUBBLE_HARD_TETHER_DISTANCE
        Ref.player.movement_velocity = Ref.player.movement_velocity.slide(direction)
        Ref.player.knockback_velocity = Ref.player.knockback_velocity.slide(direction)
        Ref.player.rope_velocity = Ref.player.rope_velocity.slide(direction)
        status_message = "Tether limit reached"
        _update_status_text()
        return

    var over_soft: float = distance - SHARED_BUBBLE_SOFT_TETHER_DISTANCE
    var soft_span: float = maxf(SHARED_BUBBLE_HARD_TETHER_DISTANCE - SHARED_BUBBLE_SOFT_TETHER_DISTANCE, 0.001)
    var pull_strength: float = clampf(over_soft / soft_span, 0.0, 1.0) * SHARED_BUBBLE_TETHER_PULL * delta
    Ref.player.global_position -= direction * pull_strength


func _get_local_skin_color() -> Color:
    if Ref.save_file_manager == null or Ref.save_file_manager.settings_file == null:
        return Color.WHITE
    return Ref.save_file_manager.settings_file.get_data("skin_modulate", Color.WHITE)


func _get_local_action_state() -> int:
    var player_hand = Ref.player.get_node_or_null("%PlayerHand")
    if player_hand == null or player_hand.current_hand == null:
        return 0
    return int(player_hand.current_hand.state)


func _get_local_break_state() -> Dictionary:
    var state: Dictionary = {
        "breaking": false,
        "break_position": Vector3i.ZERO,
        "break_block_id": 0,
        "break_progress": 0.0,
    }

    var break_behavior = Ref.player.get_node_or_null("%BreakBlocks")
    if break_behavior == null or not break_behavior.breaking or break_behavior.block == null:
        return state

    var break_goal: float = maxf(float(break_behavior.progress_goal), 0.001)
    state["breaking"] = true
    state["break_position"] = Vector3i(break_behavior.active_position)
    state["break_block_id"] = int(break_behavior.block.id)
    state["break_progress"] = clampf(float(break_behavior.progress) / break_goal, 0.0, 1.0)
    return state


func _hash_client_state(local_state: Dictionary) -> int:
    var position: Vector3 = local_state.get("position", Vector3.ZERO)
    var break_position: Vector3i = local_state.get("break_position", Vector3i.ZERO)
    return hash([
        bool(local_state.get("active", false)),
        bool(local_state.get("downed", false)),
        int(local_state.get("dimension", -1)),
        str(local_state.get("dimension_instance_key", "")),
        int(round(position.x * 20.0)),
        int(round(position.y * 20.0)),
        int(round(position.z * 20.0)),
        int(round(float(local_state.get("yaw", 0.0)) * 100.0)),
        int(round(float(local_state.get("pitch", 0.0)) * 100.0)),
        bool(local_state.get("crouching", false)),
        bool(local_state.get("grounded", true)),
        int(round(float(local_state.get("move_speed", 0.0)) * 20.0)),
        int(local_state.get("held_item_id", -1)),
        int(local_state.get("action_state", 0)),
        bool(local_state.get("breaking", false)),
        break_position.x,
        break_position.y,
        break_position.z,
        int(local_state.get("break_block_id", 0)),
        int(round(float(local_state.get("break_progress", 0.0)) * 50.0)),
    ])


func _get_local_attack_damage() -> int:
    var attack_behavior = Ref.player.get_node_or_null("%Attack")
    if attack_behavior == null:
        return 1
    return maxi(1, int(round(float(attack_behavior.damage) * float(attack_behavior.damage_modifier))))


func _get_local_attack_fire_aspect() -> bool:
    var attack_behavior = Ref.player.get_node_or_null("%Attack")
    return attack_behavior != null and bool(attack_behavior.fire_aspect)


func _serialize_item_state(item_state) -> PackedInt32Array:
    if item_state == null:
        return PackedInt32Array()
    return item_state.get_save_data()


func _deserialize_item_state(item_data: PackedInt32Array):
    if item_data.is_empty():
        return null
    var item_state = ItemState.new()
    item_state.load_from_save_data(item_data)
    return item_state


func _capture_local_persistent_state() -> Dictionary:
    if not _can_sample_player():
        return {}

    var temp_file := SaveFile.new()
    Ref.player.save_file(temp_file)
    return temp_file.data.duplicate_deep()


func _send_persistent_state_to_host(force_send: bool = false) -> void:
    if multiplayer.is_server() or not _has_live_peer() or not _can_sample_player():
        return
    if not force_send and not guest_persistent_ready:
        return

    submit_guest_persistent_state.rpc_id(
        1,
        _get_local_player_key(),
        _get_local_player_name(),
        _capture_local_persistent_state()
    )


func _store_guest_persistent_state(player_key: String, player_name: String, save_data: Dictionary) -> void:
    if not _can_share_loaded_world() or player_key == "" or save_data.is_empty():
        return

    Ref.save_file_manager.loaded_file.set_data("coop/players/%s/name" % player_key, player_name, true)
    Ref.save_file_manager.loaded_file.set_data("coop/players/%s/save_data" % player_key, save_data.duplicate_deep(), true)


func _get_guest_persistent_state(player_key: String) -> Dictionary:
    if not _can_share_loaded_world() or player_key == "":
        return {}
    var guest_data: Variant = Ref.save_file_manager.loaded_file.get_data("coop/players/%s/save_data" % player_key, {}, true)
    return guest_data.duplicate_deep() if guest_data is Dictionary else {}


func _finish_guest_character_restore() -> void:
    _clear_local_downed_state()
    local_fake_death_pending = false
    local_fake_death_save_override.clear()
    local_fake_death_respawn_target_valid = false
    clear_fake_death_override_after_shutdown = false
    handling_client_respawn = false
    remote_host_respawning = false
    client_restore_in_progress = false
    guest_persistent_ready = true
    _set_death_overlay_visible(false)
    if not multiplayer.is_server():
        reconnect_pending = false
        reconnect_attempt_count = 0
        reconnect_retry_timer = 0.0
        reconnect_reason = ""
        _set_reconnect_overlay_visible(false)
        status_message = "Joined host world"
        _update_status_text()
    _send_persistent_state_to_host(true)


func _apply_received_guest_state(save_data: Dictionary) -> void:
    if save_data.is_empty() or not _can_sample_player():
        return

    _clear_local_downed_state()
    var temp_file := SaveFile.new()
    temp_file.data = save_data.duplicate_deep()
    Ref.player.load_file(temp_file)
    Ref.player.dead = false
    Ref.player.disabled = false
    Ref.player.make_invincible_temporary()
    _finish_guest_character_restore()


func _initialize_new_guest_profile() -> void:
    if not _can_sample_player():
        return

    _clear_local_downed_state()
    var spawn_position: Vector3 = Ref.player.global_position
    var camera_angle: float = Ref.player.get_node_or_null("%Camera3D").rotation.x if Ref.player.get_node_or_null("%Camera3D") != null else 0.0
    Ref.player._on_new_game()
    var inventories: Array = [
        Ref.player_hotbar,
        Ref.player_inventory,
        Ref.player_equipment,
        Ref.player_fusion_source,
        Ref.player_fusion_result,
    ]
    for inventory in inventories:
        _clear_inventory_contents(inventory)

    Ref.player.held_item_index = 0
    Ref.player.dead = false
    Ref.player.disabled = false
    Ref.player.revive()
    Ref.player.global_position = spawn_position
    var camera: Camera3D = Ref.player.get_node_or_null("%Camera3D") as Camera3D
    if camera != null:
        camera.rotation.x = camera_angle
    Ref.player.make_invincible_temporary()
    _finish_guest_character_restore()


func _clear_inventory_contents(inventory) -> void:
    if inventory == null:
        return
    for index in range(inventory.capacity):
        inventory.set_item(index, null)


func _set_death_overlay_visible(visible: bool, subtitle: String = "Respawning...", title: String = "YOU DIED") -> void:
    if death_overlay == null:
        return
    death_overlay.visible = visible
    if visible and death_overlay_title != null:
        death_overlay_title.text = title
    if visible and death_overlay_subtitle != null:
        death_overlay_subtitle.text = subtitle


func is_local_player_fake_dead() -> bool:
    return local_fake_death_pending or handling_host_respawn or handling_client_respawn or host_respawning


func has_local_fake_death_save_override() -> bool:
    return not local_fake_death_save_override.is_empty()


func should_apply_local_fake_death_save_override() -> bool:
    return is_local_player_fake_dead() or (has_local_fake_death_save_override() and local_quit_in_progress)


func _get_local_fake_death_save_position() -> Vector3:
    if not _can_sample_player():
        return Vector3.ZERO
    if local_fake_death_respawn_target_valid:
        return local_fake_death_respawn_target

    var fallback_position: Vector3 = Ref.player.global_position
    if not Ref.player.wandering_spirit and not Ref.world.respawn_positions.is_empty():
        fallback_position = _resolve_default_respawn_fallback_position(Ref.player.global_position)

    if not _has_live_peer():
        return fallback_position

    if multiplayer.is_server():
        if _has_remote_respawn_anchor(false):
            return _find_safe_respawn_position_near(_get_remote_respawn_anchor(false, fallback_position), fallback_position)
        return fallback_position

    if _has_remote_respawn_anchor(true):
        return _find_safe_respawn_position_near(_get_remote_respawn_anchor(true, fallback_position), fallback_position)
    return fallback_position


func _build_local_fake_death_save_overrides() -> Dictionary:
    if not _can_sample_player():
        return {}

    return {
        "in_air": false,
        "global_position": _get_local_fake_death_save_position(),
        "movement_velocity": Vector3.ZERO,
        "gravity_velocity": Vector3.ZERO,
        "knockback_velocity": Vector3.ZERO,
        "rope_velocity": Vector3.ZERO,
        "health": maxi(1, Ref.player.max_health),
    }


func get_local_fake_death_save_overrides() -> Dictionary:
    if has_local_fake_death_save_override():
        return local_fake_death_save_override.duplicate(true)
    if not is_local_player_fake_dead():
        return {}
    return _build_local_fake_death_save_overrides()


func _stabilize_local_player_after_fake_death(restore_control: bool = true) -> void:
    if not is_instance_valid(Ref.player):
        return

    if Ref.player.health <= 0:
        Ref.player.health = maxi(1, Ref.player.max_health)
    Ref.player.dead = false
    _reset_local_player_motion()
    if restore_control:
        Ref.player.disabled = false


func _abort_host_respawn(sync_remote_state: bool = false, broadcast_state: bool = false) -> void:
    var had_host_respawn: bool = handling_host_respawn or host_respawning
    if had_host_respawn:
        host_respawn_sequence += 1

    if not local_fake_death_respawn_target_valid:
        local_fake_death_respawn_target = _get_local_fake_death_save_position()
        local_fake_death_respawn_target_valid = true
    if local_fake_death_save_override.is_empty():
        local_fake_death_save_override = _build_local_fake_death_save_overrides()
    if local_fake_death_respawn_target_valid and _can_sample_player():
        _teleport_local_player_exact(local_fake_death_respawn_target)
    local_fake_death_pending = false
    handling_host_respawn = false
    host_respawning = false
    _set_death_overlay_visible(false)
    _stabilize_local_player_after_fake_death()

    if sync_remote_state and _has_live_peer():
        sync_host_respawn_state.rpc(false)
    if broadcast_state and _has_live_peer():
        _broadcast_local_state_now()


func _stop_local_player_actions() -> void:
    if not _can_sample_player():
        return

    var break_behavior = Ref.player.get_node_or_null("%BreakBlocks")
    if break_behavior != null:
        break_behavior.break_block_stop()

    if is_instance_valid(Ref.player.held_item):
        Ref.player.held_item.interact_end()


func _reset_local_player_motion() -> void:
    if not _can_sample_player():
        return

    Ref.player.movement_velocity = Vector3.ZERO
    Ref.player.gravity_velocity = Vector3.ZERO
    Ref.player.knockback_velocity = Vector3.ZERO
    Ref.player.rope_velocity = Vector3.ZERO
    Ref.player.velocity = Vector3.ZERO


func _teleport_local_player_exact(target_position: Vector3) -> void:
    if not _can_sample_player():
        return

    Ref.player.global_position = target_position
    _reset_local_player_motion()


func _resolve_safe_position_near_player(target_position: Vector3) -> Vector3:
    var fallback_position: Vector3 = target_position + Vector3(1.5, 0.0, 0.0)
    return _find_safe_respawn_position_near(target_position, fallback_position)


func _close_pause_menu_if_open() -> void:
    if Ref.game_menu == null:
        return
    if int(Ref.game_menu.state) == 4 and Ref.game_menu.has_method("close_pause"):
        Ref.game_menu.close_pause()


func _is_safe_respawn_position(world_position: Vector3) -> bool:
    if not is_instance_valid(Ref.world):
        return true

    var feet_position: Vector3 = world_position
    var body_position: Vector3 = world_position + Vector3(0.0, 1.0, 0.0)
    var floor_position: Vector3 = world_position + Vector3(0.0, -1.0, 0.0)
    if not Ref.world.is_position_loaded(feet_position) or not Ref.world.is_position_loaded(body_position) or not Ref.world.is_position_loaded(floor_position):
        return false
    if Ref.world.is_block_solid_at(feet_position) or Ref.world.is_block_solid_at(body_position):
        return false
    if not Ref.world.is_block_solid_at(floor_position):
        return false
    if Ref.world.get_water_level_at(feet_position) > 0 or Ref.world.get_water_level_at(body_position) > 0:
        return false
    return true


func _find_safe_respawn_position_near(anchor_position: Vector3, fallback_position: Vector3) -> Vector3:
    var centered_anchor: Vector3 = anchor_position.floor() + Vector3(0.5, 0.0, 0.5)
    var offsets: Array[Vector3] = [
        Vector3(1.5, 0.0, 0.0),
        Vector3(-1.5, 0.0, 0.0),
        Vector3(0.0, 0.0, 1.5),
        Vector3(0.0, 0.0, -1.5),
        Vector3(1.5, 0.0, 1.5),
        Vector3(-1.5, 0.0, 1.5),
        Vector3(1.5, 0.0, -1.5),
        Vector3(-1.5, 0.0, -1.5),
        Vector3(0.0, 1.0, 0.0),
        Vector3(1.5, 1.0, 0.0),
        Vector3(-1.5, 1.0, 0.0),
        Vector3(0.0, 1.0, 1.5),
        Vector3(0.0, 1.0, -1.5),
    ]

    for offset in offsets:
        var candidate: Vector3 = centered_anchor + offset
        if _is_safe_respawn_position(candidate):
            return candidate

    var default_candidate: Vector3 = centered_anchor + Vector3(1.5, 0.0, 0.0)
    if _is_safe_respawn_position(default_candidate):
        return default_candidate
    return fallback_position


func _has_remote_respawn_anchor(prefer_host_peer: bool) -> bool:
    if not _has_live_peer() or not _can_sample_player():
        return false
    if not multiplayer.is_server() and prefer_host_peer and remote_host_respawning:
        return false

    var active_instance_key: String = get_active_dimension_instance_key()
    for peer_id in peer_states.keys():
        var int_peer_id: int = int(peer_id)
        if multiplayer.is_server():
            if int_peer_id == 1:
                continue
        elif prefer_host_peer and int_peer_id != 1:
            continue

        var state: Dictionary = peer_states[peer_id]
        if _is_peer_state_same_instance(state, active_instance_key):
            return true
    return false


func _get_remote_respawn_anchor(prefer_host_peer: bool, fallback_position: Vector3) -> Vector3:
    if not _has_live_peer() or not _can_sample_player():
        return fallback_position
    if not multiplayer.is_server() and prefer_host_peer and remote_host_respawning:
        return fallback_position

    var active_instance_key: String = get_active_dimension_instance_key()
    var nearest_position: Vector3 = fallback_position
    var nearest_distance_squared: float = INF

    for peer_id in peer_states.keys():
        var int_peer_id: int = int(peer_id)
        if multiplayer.is_server():
            if int_peer_id == 1:
                continue
        elif prefer_host_peer and int_peer_id != 1:
            continue

        var state: Dictionary = peer_states[peer_id]
        if not _is_peer_state_same_instance(state, active_instance_key):
            continue

        var peer_position: Vector3 = state.get("position", fallback_position)
        if prefer_host_peer and int_peer_id == 1:
            return peer_position

        var distance_squared: float = fallback_position.distance_squared_to(peer_position)
        if distance_squared >= nearest_distance_squared:
            continue
        nearest_distance_squared = distance_squared
        nearest_position = peer_position

    return nearest_position


func _resolve_default_respawn_fallback_position(origin_position: Vector3) -> Vector3:
    if not _can_sample_player():
        return origin_position
    if local_fake_death_respawn_target_valid:
        return local_fake_death_respawn_target

    if not Ref.player.wandering_spirit and not Ref.world.respawn_positions.is_empty():
        var closest_position: Vector3i = Ref.world.respawn_positions.keys()[0]
        for position in Ref.world.respawn_positions:
            if position.distance_to(origin_position) < closest_position.distance_to(origin_position):
                closest_position = position
        return Vector3(closest_position) + Vector3(0.5, 0.0, 0.5)

    var centered_origin: Vector3 = origin_position.floor() + Vector3(0.5, 0.0, 0.5)
    return _find_safe_respawn_position_near(centered_origin, centered_origin + Vector3(0.0, 1.0, 0.0))


func _resolve_respawn_position() -> Vector3:
    if not _can_sample_player():
        return Vector3.ZERO

    if not Ref.player.wandering_spirit and not Ref.world.respawn_positions.is_empty():
        return _resolve_default_respawn_fallback_position(Ref.player.global_position)

    var fallback_position: Vector3 = Ref.player.global_position
    var found_spawn: bool = await Ref.world.spawn_tester.find_spawn_position(
        Ref.player.global_position if Ref.player.wandering_spirit else Vector3.ZERO,
        Ref.world.current_dimension,
        3.0 if Ref.player.wandering_spirit else 1.0
    )
    return Ref.player.global_position if found_spawn else fallback_position


func _broadcast_local_state_now() -> void:
    if not _has_live_peer():
        return

    var local_state: Dictionary = _capture_local_state_for_send()
    if multiplayer.is_server():
        peer_states[1] = local_state
        _refresh_markers(peer_states, multiplayer.get_unique_id())
        host_snapshot_sequence += 1
        server_snapshot_reliable.rpc(host_snapshot_sequence, _serialize_peer_states())
    else:
        last_sent_client_state_hash = _hash_client_state(local_state)
        client_state_heartbeat_timer = 0.0
        submit_client_state_reliable.rpc_id(
            1,
            int(local_state.get("sequence", 0)),
            local_state.get("active", false),
            bool(local_state.get("downed", false)),
            local_state.get("dimension", -1),
            str(local_state.get("dimension_instance_key", "")),
            str(local_state.get("pocket_owner_key", "")),
            local_state.get("position", Vector3.ZERO),
            local_state.get("yaw", 0.0),
            local_state.get("pitch", 0.0),
            local_state.get("crouching", false),
            local_state.get("grounded", true),
            local_state.get("move_speed", 0.0),
            bool(local_state.get("under_water", false)),
            local_state.get("held_item_id", -1),
            local_state.get("action_state", 0),
            str(local_state.get("name", "guest")),
            str(local_state.get("player_key", "")),
            str(local_state.get("avatar_id", DEFAULT_AVATAR_ID)),
            local_state.get("skin_color", Color.WHITE),
            bool(local_state.get("breaking", false)),
            local_state.get("break_position", Vector3i.ZERO),
            int(local_state.get("break_block_id", 0)),
            float(local_state.get("break_progress", 0.0))
        )


func _capture_local_world_patch() -> Dictionary:
    if not _can_sample_player():
        return {}

    var dimension: int = int(Ref.world.current_dimension)
    var pocket_owner_key: String = get_active_pocket_owner_key()
    var prefix: String = _resolve_dimension_namespace(dimension, pocket_owner_key) + "_"
    var world_data: Dictionary = {}
    Ref.world.save_data(world_data, prefix)

    return {
        "dimension": dimension,
        "pocket_owner_key": pocket_owner_key,
        "dimension_instance_key": get_dimension_instance_key(dimension, pocket_owner_key),
        "respawn_positions": Ref.world.respawn_positions.duplicate(true),
        "world_data": world_data,
    }


func _merge_world_patch_into_save(world_patch: Dictionary) -> void:
    if Ref.save_file_manager == null or Ref.save_file_manager.loaded_file == null:
        return

    var world_data: Variant = world_patch.get("world_data", {})
    if world_data is Dictionary:
        Ref.save_file_manager.loaded_file.data.merge(world_data, true)

    var dimension_namespace: String = _resolve_dimension_namespace(int(world_patch.get("dimension", -1)), str(world_patch.get("pocket_owner_key", "")))
    SaveFile._set_data(Ref.save_file_manager.loaded_file.data, dimension_namespace + "/respawn_positions", world_patch.get("respawn_positions", {}))


func _apply_world_patch_locally(world_patch: Dictionary) -> void:
    if not _can_sample_player():
        return

    var dimension: int = int(world_patch.get("dimension", -1))
    var pocket_owner_key: String = str(world_patch.get("pocket_owner_key", ""))
    if get_dimension_instance_key(dimension, pocket_owner_key) != get_active_dimension_instance_key():
        return

    _merge_world_patch_into_save(world_patch)
    Ref.world.respawn_positions = world_patch.get("respawn_positions", {}).duplicate(true)
    Ref.world.load_data(world_patch.get("world_data", {}), _resolve_dimension_namespace(dimension, pocket_owner_key) + "_")
    Ref.world.force_reload()


func _send_local_world_patch_if_needed(force_send: bool = false) -> void:
    return


func is_client_session() -> bool:
    return _has_live_peer() and not multiplayer.is_server()


func play_local_damage_feedback(damage: int) -> void:
    if not _can_sample_player():
        return

    var camera = Ref.player.get_node_or_null("%Camera3D")
    if camera != null:
        camera.camera_shake(0.2, 0.04)

    var harm_cover = Ref.player.get_node_or_null("%HarmCover")
    if harm_cover != null and "_on_damage_taken" in harm_cover:
        harm_cover._on_damage_taken(maxi(1, damage))


func _can_sample_player() -> bool:
    return is_instance_valid(Ref.main) and is_instance_valid(Ref.world) and is_instance_valid(Ref.player) and Ref.main.loaded and Ref.world.load_enabled


func _get_rotation_pivot() -> Node3D:
    return Ref.player.get_node_or_null("%RotationPivot") as Node3D


func _get_entity_visual_yaw(entity) -> float:
    if entity == null or not is_instance_valid(entity):
        return 0.0
    var rotation_pivot: Node3D = entity.get_node_or_null("%RotationPivot") as Node3D
    return rotation_pivot.rotation.y if rotation_pivot != null else entity.rotation.y


func _set_entity_visual_yaw(entity, yaw: float) -> void:
    if entity == null or not is_instance_valid(entity):
        return
    var rotation_pivot: Node3D = entity.get_node_or_null("%RotationPivot") as Node3D
    if rotation_pivot != null:
        rotation_pivot.rotation.y = yaw
    else:
        entity.rotation.y = yaw


func _get_entity_total_velocity(entity) -> Vector3:
    if entity == null or not is_instance_valid(entity):
        return Vector3.ZERO
    if entity is Entity:
        return entity.movement_velocity + entity.gravity_velocity + entity.knockback_velocity + entity.rope_velocity
    if "velocity" in entity:
        return entity.velocity
    return Vector3.ZERO


func _quantize_float(value: float, step: float = 0.05) -> float:
    if step <= 0.0:
        return value
    return snappedf(value, step)


func _quantize_vector3(value: Vector3, step: float = 0.1) -> Vector3:
    if step <= 0.0:
        return value
    return Vector3(
        snappedf(value.x, step),
        snappedf(value.y, step),
        snappedf(value.z, step)
    )


func _get_object_script_path(target: Object) -> String:
    if target == null or target.get_script() == null:
        return ""
    return str(target.get_script().resource_path)


func _is_entity_model_node(node: Object) -> bool:
    if node == null:
        return false
    if node.get_class() == "EntityModel":
        return true
    return _object_has_property(node, "look_target") and _object_has_property(node, "look_ratio")


func _find_first_entity_model(root: Node):
    if root == null or not is_instance_valid(root):
        return null
    if root.has_meta("coop_entity_model_node"):
        var cached_model = root.get_meta("coop_entity_model_node")
        if is_instance_valid(cached_model):
            return cached_model
        if str(cached_model) == "false":
            return null
        root.remove_meta("coop_entity_model_node")
    var found = _search_first_entity_model(root)
    root.set_meta("coop_entity_model_node", found if found != null else false)
    return found


func _search_first_entity_model(root: Node):
    if _is_entity_model_node(root):
        return root
    for child in root.get_children():
        var found = _search_first_entity_model(child)
        if found != null:
            return found
    return null


func _capture_entity_model_head_look_state(root: Node) -> Dictionary:
    var model = _find_first_entity_model(root)
    if model == null:
        return {}

    var state: Dictionary = {}
    if _object_has_property(model, "look_ratio"):
        state["look_ratio"] = float(model.get("look_ratio"))
    if _object_has_property(model, "look_target"):
        state["look_target"] = model.get("look_target")
    return state


func _apply_entity_model_head_look_state(root: Node, state: Dictionary) -> void:
    if state.is_empty():
        return

    var model = _find_first_entity_model(root)
    if model == null:
        return

    if state.has("look_ratio") and _object_has_property(model, "look_ratio"):
        model.set("look_ratio", float(state.get("look_ratio", 0.0)))
    if state.has("look_target") and _object_has_property(model, "look_target"):
        model.set("look_target", state.get("look_target", Vector3.ZERO))


func _capture_node_local_rotation(node: Node3D) -> Variant:
    if node == null or not is_instance_valid(node):
        return null
    return node.rotation


func _capture_entity_procedural_visual_state(entity) -> Dictionary:
    if entity == null or not is_instance_valid(entity):
        return {}

    var state: Dictionary = {}
    var rotation_pivot: Node3D = entity.get_node_or_null("%RotationPivot") as Node3D
    if rotation_pivot != null:
        state["rotation_pivot_rotation"] = rotation_pivot.rotation

    if _object_has_property(entity, "look_direction"):
        state["look_direction"] = entity.get("look_direction")
    if _object_has_property(entity, "time"):
        state["time"] = _quantize_float(float(entity.get("time")), 0.01)
    if _object_has_property(entity, "flap_speed"):
        state["flap_speed"] = _quantize_float(float(entity.get("flap_speed")), 0.01)
    if _object_has_property(entity, "angle"):
        state["angle"] = _quantize_float(float(entity.get("angle")), 0.01)
    if _object_has_property(entity, "rotate_axis"):
        state["rotate_axis"] = bool(entity.get("rotate_axis"))
    if _object_has_property(entity, "state"):
        state["state"] = int(entity.get("state"))
    if _object_has_property(entity, "teleport_amount"):
        state["teleport_amount"] = _quantize_float(float(entity.get("teleport_amount")), 0.01)
    if _object_has_property(entity, "direction"):
        state["direction"] = _quantize_vector3(entity.get("direction"), 0.01)
    if _object_has_property(entity, "look_target"):
        state["look_target"] = entity.get("look_target")

    var body_model: Node3D = entity.get_node_or_null("%BodyModel") as Node3D
    if body_model != null:
        state["body_model_rotation"] = body_model.rotation

    var body: Node3D = entity.get_node_or_null("%Body") as Node3D
    if body != null:
        state["body_rotation"] = body.rotation

    var wing_holder_1: Node3D = entity.get_node_or_null("%WingHolder1") as Node3D
    if wing_holder_1 != null:
        state["wing_holder_1_rotation"] = wing_holder_1.rotation

    var wing_holder_2: Node3D = entity.get_node_or_null("%WingHolder2") as Node3D
    if wing_holder_2 != null:
        state["wing_holder_2_rotation"] = wing_holder_2.rotation

    var fish_model = entity.get_node_or_null("%FishModel")
    if fish_model != null and is_instance_valid(fish_model):
        if fish_model is Node3D:
            state["fish_model_rotation"] = (fish_model as Node3D).rotation
        if _object_has_property(fish_model, "panic"):
            state["fish_panic"] = _quantize_float(float(fish_model.get("panic")), 0.01)
        if _object_has_property(fish_model, "speed"):
            state["fish_speed"] = _quantize_float(float(fish_model.get("speed")), 0.01)
        if _object_has_property(fish_model, "time"):
            state["fish_time"] = _quantize_float(float(fish_model.get("time")), 0.01)

    var boid_model: Node3D = entity.get_node_or_null("%BoidModel") as Node3D
    if boid_model != null:
        state["boid_model_rotation"] = boid_model.rotation

    var glaggler_model: Node3D = entity.get_node_or_null("%GlagglerModel") as Node3D
    if glaggler_model != null:
        state["glaggler_model_rotation"] = glaggler_model.rotation

    var leg_rests: Node3D = entity.get_node_or_null("%LegRests") as Node3D
    if leg_rests != null:
        state["leg_rests_rotation"] = leg_rests.rotation

    var leg_rays: Node3D = entity.get_node_or_null("%LegRays") as Node3D
    if leg_rays != null:
        state["leg_rays_rotation"] = leg_rays.rotation

    var core: Node3D = entity.get_node_or_null("%Core") as Node3D
    if core != null:
        state["core_rotation"] = core.rotation

    return state


func _apply_node_local_rotation(node: Node3D, target_rotation: Variant, weight: float = 1.0) -> void:
    if node == null or not is_instance_valid(node) or not (target_rotation is Vector3):
        return
    var rotation_value: Vector3 = target_rotation
    if weight >= 1.0:
        node.rotation = rotation_value
        return
    node.rotation = Vector3(
        lerp_angle(node.rotation.x, rotation_value.x, weight),
        lerp_angle(node.rotation.y, rotation_value.y, weight),
        lerp_angle(node.rotation.z, rotation_value.z, weight)
    )


func _apply_entity_procedural_visual_state(entity, state: Dictionary, lerp_weight: float = 1.0) -> void:
    if entity == null or not is_instance_valid(entity) or state.is_empty():
        return

    entity.set_meta("coop_procedural_visual_state", state.duplicate(true))

    if state.has("look_direction") and _object_has_property(entity, "look_direction"):
        entity.set("look_direction", state.get("look_direction", Vector3.ZERO))
    if state.has("time") and _object_has_property(entity, "time"):
        entity.set("time", float(state.get("time", 0.0)))
    if state.has("angle") and _object_has_property(entity, "angle"):
        entity.set("angle", float(state.get("angle", 0.0)))
    if state.has("state") and _object_has_property(entity, "state"):
        entity.set("state", int(state.get("state", 0)))
    if state.has("teleport_amount") and _object_has_property(entity, "teleport_amount"):
        entity.set("teleport_amount", float(state.get("teleport_amount", 0.0)))
    if state.has("direction") and _object_has_property(entity, "direction"):
        entity.set("direction", state.get("direction", Vector3.ZERO))
    if state.has("look_target") and _object_has_property(entity, "look_target"):
        entity.set("look_target", state.get("look_target", Vector3.ZERO))

    _apply_node_local_rotation(entity.get_node_or_null("%RotationPivot") as Node3D, state.get("rotation_pivot_rotation", null), lerp_weight)
    _apply_node_local_rotation(entity.get_node_or_null("%BodyModel") as Node3D, state.get("body_model_rotation", null), lerp_weight)
    _apply_node_local_rotation(entity.get_node_or_null("%Body") as Node3D, state.get("body_rotation", null), lerp_weight)
    _apply_node_local_rotation(entity.get_node_or_null("%WingHolder1") as Node3D, state.get("wing_holder_1_rotation", null), lerp_weight)
    _apply_node_local_rotation(entity.get_node_or_null("%WingHolder2") as Node3D, state.get("wing_holder_2_rotation", null), lerp_weight)
    _apply_node_local_rotation(entity.get_node_or_null("%BoidModel") as Node3D, state.get("boid_model_rotation", null), lerp_weight)
    _apply_node_local_rotation(entity.get_node_or_null("%GlagglerModel") as Node3D, state.get("glaggler_model_rotation", null), lerp_weight)
    _apply_node_local_rotation(entity.get_node_or_null("%LegRests") as Node3D, state.get("leg_rests_rotation", null), lerp_weight)
    _apply_node_local_rotation(entity.get_node_or_null("%LegRays") as Node3D, state.get("leg_rays_rotation", null), lerp_weight)
    _apply_node_local_rotation(entity.get_node_or_null("%Core") as Node3D, state.get("core_rotation", null), lerp_weight)

    var fish_model = entity.get_node_or_null("%FishModel")
    if fish_model != null and is_instance_valid(fish_model):
        if state.has("fish_panic") and _object_has_property(fish_model, "panic"):
            fish_model.set("panic", float(state.get("fish_panic", 0.0)))
        if state.has("fish_speed") and _object_has_property(fish_model, "speed"):
            fish_model.set("speed", float(state.get("fish_speed", 0.0)))
        if state.has("fish_time") and _object_has_property(fish_model, "time"):
            fish_model.set("time", float(state.get("fish_time", 0.0)))
        if fish_model is Node3D:
            _apply_node_local_rotation(fish_model as Node3D, state.get("fish_model_rotation", null), lerp_weight)

func _orient_entity_rotation_pivot(entity, direction: Vector3) -> void:
    if entity == null or not is_instance_valid(entity):
        return
    var rotation_pivot: Node3D = entity.get_node_or_null("%RotationPivot") as Node3D
    if rotation_pivot == null or direction.length_squared() <= 0.0001:
        return
    SpatialMath.look_at(rotation_pivot, rotation_pivot.global_position + direction.normalized())


func _step_client_bee_visuals(entity, delta: float) -> void:
    if entity == null or not is_instance_valid(entity):
        return

    if _object_has_property(entity, "look_direction"):
        var look_direction: Vector3 = entity.get("look_direction")
        look_direction = look_direction.lerp(entity.movement_velocity, clampf(delta * 2.0, 0.0, 1.0))
        entity.set("look_direction", look_direction)
        _orient_entity_rotation_pivot(entity, look_direction)

    var body_model: Node3D = entity.get_node_or_null("%BodyModel") as Node3D
    if body_model != null:
        body_model.rotation.z = lerp_angle(body_model.rotation.z, 0.0, clampf(delta * 8.0, 0.0, 1.0))

    if _object_has_property(entity, "time"):
        var flap_speed: float = float(entity.get("flap_speed")) if _object_has_property(entity, "flap_speed") else 0.0
        if flap_speed > 0.0:
            entity.set("time", float(entity.get("time")) + delta * flap_speed)
    if entity.has_method("wing_update"):
        entity.call("wing_update")


func _step_client_boid_visuals(entity, delta: float) -> void:
    if entity == null or not is_instance_valid(entity):
        return

    if _object_has_property(entity, "look_direction"):
        var look_direction: Vector3 = entity.get("look_direction")
        look_direction = look_direction.lerp(entity.movement_velocity, clampf(delta * 6.5, 0.0, 1.0))
        entity.set("look_direction", look_direction)
        _orient_entity_rotation_pivot(entity, look_direction)

    var boid_model: Node3D = entity.get_node_or_null("%BoidModel") as Node3D
    if boid_model != null:
        boid_model.rotation.z = lerp_angle(boid_model.rotation.z, 0.0, clampf(delta * 8.0, 0.0, 1.0))


func _step_client_fish_visuals(entity, delta: float) -> void:
    if entity == null or not is_instance_valid(entity):
        return

    var fish_model = entity.get_node_or_null("%FishModel")
    if fish_model == null or not is_instance_valid(fish_model):
        return

    var look_direction: Vector3 = entity.get("look_direction") if _object_has_property(entity, "look_direction") else Vector3.ZERO
    var state_value: int = int(entity.get("state")) if _object_has_property(entity, "state") else 0
    if state_value == 1:
        look_direction = look_direction.lerp(Vector3(0, 0, 1), clampf(delta * 1.0, 0.0, 1.0))
        if fish_model is Node3D:
            (fish_model as Node3D).rotation.z = lerp_angle((fish_model as Node3D).rotation.z, 1.5708, clampf(delta * 8.0, 0.0, 1.0))
        if _object_has_property(fish_model, "panic"):
            fish_model.set("panic", lerpf(float(fish_model.get("panic")), 1.0, clampf(delta * 8.0, 0.0, 1.0)))
    else:
        look_direction = look_direction.lerp(entity.movement_velocity, clampf(delta * 6.0, 0.0, 1.0))
        if fish_model is Node3D:
            (fish_model as Node3D).rotation.z = lerp_angle((fish_model as Node3D).rotation.z, 0.0, clampf(delta * 8.0, 0.0, 1.0))
        if _object_has_property(fish_model, "panic"):
            fish_model.set("panic", lerpf(float(fish_model.get("panic")), 0.0, clampf(delta * 8.0, 0.0, 1.0)))

    if _object_has_property(entity, "look_direction"):
        entity.set("look_direction", look_direction)
    _orient_entity_rotation_pivot(entity, look_direction)

    if _object_has_property(fish_model, "speed"):
        var base_speed: float = _resolve_object_float_property(entity, ["speed"], 1.0)
        var speed_modifier: float = _resolve_object_float_property(entity, ["speed_modifier"], 1.0)
        var speed_ratio: float = entity.velocity.length() / maxf(base_speed * speed_modifier, 0.001)
        fish_model.set("speed", lerpf(float(fish_model.get("speed")), speed_ratio, clampf(delta * 3.0, 0.0, 1.0)))


func _step_client_glaggler_visuals(entity, delta: float) -> void:
    if entity == null or not is_instance_valid(entity) or not _object_has_property(entity, "look_direction"):
        return
    var horizontal_direction: Vector3 = Vector3(entity.movement_velocity.x, 0.0, entity.movement_velocity.z)
    if horizontal_direction.length_squared() <= 0.0001:
        return
    var look_direction: Vector3 = entity.get("look_direction")
    look_direction = look_direction.lerp(horizontal_direction.normalized(), clampf(delta * 0.2, 0.0, 1.0))
    entity.set("look_direction", look_direction)
    var rotation_pivot: Node3D = entity.get_node_or_null("%RotationPivot") as Node3D
    if rotation_pivot != null:
        SpatialMath.look_at_local(rotation_pivot, look_direction)


func _step_client_shark_visuals(entity, delta: float) -> void:
    if entity == null or not is_instance_valid(entity):
        return
    if _object_has_property(entity, "time"):
        entity.set("time", float(entity.get("time")) + delta * 0.1)
    var body: Node3D = entity.get_node_or_null("%Body") as Node3D
    if body != null:
        var spin_per_speed: float = float(entity.get("spin_per_speed")) if _object_has_property(entity, "spin_per_speed") else 0.0
        body.rotation.x += delta * spin_per_speed * entity.velocity.length()
    var rotation_pivot: Node3D = entity.get_node_or_null("%RotationPivot") as Node3D
    if rotation_pivot != null and entity.movement_velocity.length_squared() > 0.0001:
        SpatialMath.look_at_local(rotation_pivot, -entity.movement_velocity.normalized())


func _step_client_diatom_visuals(entity, _delta: float) -> void:
    if entity == null or not is_instance_valid(entity):
        return
    var direction: Vector3 = Vector3(entity.movement_velocity.x, 0.0, entity.movement_velocity.z).normalized()
    if direction.length_squared() <= 0.0001:
        return
    var leg_rests: Node3D = entity.get_node_or_null("%LegRests") as Node3D
    if leg_rests != null:
        SpatialMath.look_at_local(leg_rests, direction)
    var leg_rays: Node3D = entity.get_node_or_null("%LegRays") as Node3D
    if leg_rays != null:
        SpatialMath.look_at_local(leg_rays, direction)
    var core: Node3D = entity.get_node_or_null("%Core") as Node3D
    if core != null:
        SpatialMath.look_at_local(core, direction)


func _advance_client_animation_tree(entity, delta: float) -> void:
    var animation_tree: AnimationTree = _find_first_animation_tree(entity)
    if animation_tree == null:
        return
    animation_tree.active = true
    if not bool(animation_tree.get_meta("coop_manual_advance_initialized", false)):
        animation_tree.set_meta("coop_manual_advance_initialized", true)
        animation_tree.set_process(false)
        animation_tree.set_physics_process(false)
        var animation_player: AnimationPlayer = _find_first_animation_player(entity)
        if animation_player != null:
            animation_player.set_process(false)
            animation_player.set_physics_process(false)
    animation_tree.advance(delta)


func _update_client_procedural_entity_visuals(entity, delta: float) -> void:
    if entity == null or not is_instance_valid(entity):
        return

    var state = entity.get_meta("coop_procedural_visual_state", {}) if entity.has_meta("coop_procedural_visual_state") else {}
    if state is Dictionary and not state.is_empty():
        var lerp_weight: float = clampf(delta * 12.0, 0.0, 1.0)
        _apply_entity_procedural_visual_state(entity, state, lerp_weight)

    var script_path: String = _get_object_script_path(entity)
    if script_path.ends_with("/bee.gd"):
        _step_client_bee_visuals(entity, delta)
    elif script_path.ends_with("/boid.gd"):
        _step_client_boid_visuals(entity, delta)
    elif script_path.ends_with("/fish.gd"):
        _step_client_fish_visuals(entity, delta)
    elif script_path.ends_with("/glaggler.gd"):
        _step_client_glaggler_visuals(entity, delta)
    elif script_path.ends_with("/shark.gd"):
        _step_client_shark_visuals(entity, delta)
    elif script_path.ends_with("/diatom.gd"):
        _step_client_diatom_visuals(entity, delta)


func calculate_attack_knockback_velocity(target, attacker_position: Vector3, attacker_velocity: Vector3, knockback_strength: float, fly_strength: float) -> Vector3:
    if target == null or not is_instance_valid(target):
        return Vector3.ZERO

    var horizontal_kb: Vector3 = target.global_position - attacker_position
    horizontal_kb.y = 0.0
    if not horizontal_kb.is_zero_approx():
        horizontal_kb = horizontal_kb.normalized()

    var jump_modifier: float = float(target.get("jump_modifier")) if _object_has_property(target, "jump_modifier") else 1.0
    var on_floor: bool = false
    if is_remote_player_proxy(target) and _object_has_property(target, "grounded"):
        on_floor = bool(target.get("grounded"))
    elif target.has_method("is_on_floor"):
        on_floor = target.is_on_floor()
    var knockback_velocity: Vector3 = 0.45 * attacker_velocity + horizontal_kb * knockback_strength
    knockback_velocity.y += knockback_strength * jump_modifier * fly_strength * (0.5 if not on_floor else 1.0)
    return knockback_velocity


func _serialize_peer_states() -> Array:
    var snapshot: Array = []
    for peer_id in peer_states.keys():
        var state: Dictionary = peer_states[peer_id]
        snapshot.append([
            int(peer_id),
            bool(state.get("active", false)),
            bool(state.get("downed", false)),
            int(state.get("dimension", -1)),
            str(state.get("dimension_instance_key", "")),
            str(state.get("pocket_owner_key", "")),
            state.get("position", Vector3.ZERO),
            float(state.get("yaw", 0.0)),
            float(state.get("pitch", 0.0)),
            bool(state.get("crouching", false)),
            bool(state.get("grounded", true)),
            float(state.get("move_speed", 0.0)),
            int(state.get("held_item_id", -1)),
            int(state.get("action_state", 0)),
            str(state.get("name", "Peer %s" % int(peer_id))),
            str(state.get("player_key", "")),
            str(state.get("avatar_id", DEFAULT_AVATAR_ID)),
            state.get("skin_color", Color.WHITE),
            bool(state.get("breaking", false)),
            state.get("break_position", Vector3i.ZERO),
            int(state.get("break_block_id", 0)),
            float(state.get("break_progress", 0.0)),
        ])
    return snapshot


func _refresh_markers(states: Dictionary, local_peer_id: int) -> void:
    var visible_ids: Dictionary = {}
    var active_instance_key: String = get_active_dimension_instance_key() if _can_sample_player() else ""
    for peer_id in states.keys():
        var int_peer_id: int = int(peer_id)
        if int_peer_id == local_peer_id:
            continue

        visible_ids[int_peer_id] = true
        var state: Dictionary = states[peer_id]
        var downed: bool = bool(state.get("downed", false))
        var same_dimension: bool = _can_sample_player() and str(state.get("dimension_instance_key", "")) == active_instance_key
        var marker: Node = _ensure_marker(int_peer_id)
        marker.set_avatar_id(str(state.get("avatar_id", DEFAULT_AVATAR_ID)))
        var display_name: String = str(state.get("name", "Peer %s" % int_peer_id))
        marker.set_display_name("%s [DOWN]" % display_name if downed else display_name)
        marker.set_held_item_id(int(state.get("held_item_id", -1)))
        marker.set_skin_color(state.get("skin_color", Color.WHITE))
        marker.apply_state(
            bool(state.get("active", false)) and same_dimension,
            state.get("position", Vector3.ZERO),
            float(state.get("yaw", 0.0)),
            float(state.get("pitch", 0.0)),
            bool(state.get("crouching", false)) or downed,
            bool(state.get("grounded", true)),
            float(state.get("move_speed", 0.0)),
            int(state.get("action_state", 0))
        )
        _update_remote_break_outline(int_peer_id, same_dimension, state)

        if same_dimension and bool(state.get("active", false)):
            var proxy = _ensure_remote_player_proxy(int_peer_id)
            if proxy != null:
                _update_remote_player_proxy(proxy, state)
        elif remote_player_proxies.has(int_peer_id):
            _remove_remote_player_proxy(int_peer_id)

    for peer_id in markers.keys().duplicate():
        if not visible_ids.has(peer_id):
            markers[peer_id].call_deferred("queue_free")
            markers.erase(peer_id)
            _remove_remote_break_outline(peer_id)

    for peer_id in remote_player_proxies.keys().duplicate():
        if not visible_ids.has(peer_id):
            _remove_remote_player_proxy(int(peer_id))


func _ensure_marker(peer_id: int) -> Node:
    if markers.has(peer_id):
        return markers[peer_id]

    var marker_script: GDScript = load("res://coop_mod/remote_player_marker.gd")
    var marker: Node = marker_script.new()
    marker.name = "RemotePeer%s" % peer_id
    add_child(marker)
    marker.setup(peer_id)
    markers[peer_id] = marker
    return marker


func _clear_markers() -> void:
    for peer_id in markers.keys():
        markers[peer_id].call_deferred("queue_free")
    markers.clear()
    _clear_remote_player_proxies()
    _clear_remote_break_outlines()


func _hide_all_markers() -> void:
    for peer_id in markers.keys():
        markers[peer_id].visible = false
    _clear_remote_player_proxies()
    _clear_remote_break_outlines()


func _ensure_remote_player_proxy(peer_id: int):
    if remote_player_proxies.has(peer_id) and is_instance_valid(remote_player_proxies[peer_id]):
        return remote_player_proxies[peer_id]

    var proxy_scene = load(REMOTE_PROXY_SCENE_PATH)
    if not (proxy_scene is PackedScene):
        return null

    var proxy = proxy_scene.instantiate()
    if proxy == null:
        return null

    proxy.name = "RemotePlayerProxy%s" % peer_id
    proxy.set_meta("coop_remote_player_proxy", true)
    proxy.set_meta("coop_remote_player_proxy_peer_id", peer_id)
    get_tree().get_root().add_child(proxy)

    proxy.dead = false
    proxy.disabled = false

    remote_player_proxies[peer_id] = proxy
    return proxy


func _update_remote_player_proxy(proxy, state: Dictionary) -> void:
    if proxy == null or not is_instance_valid(proxy) or not proxy.is_inside_tree():
        return

    if proxy.has_method("apply_remote_state"):
        proxy.apply_remote_state(state)
        return

    var downed: bool = bool(state.get("downed", false))
    proxy.global_position = state.get("position", Vector3.ZERO)
    proxy.velocity = Vector3.ZERO
    proxy.dead = false
    proxy.disabled = downed
    proxy.under_water = bool(state.get("under_water", false))
    if proxy.has_method("set_crouching"):
        proxy.set_crouching(bool(state.get("crouching", false)) or downed)


func _remove_remote_player_proxy(peer_id: int) -> void:
    if not remote_player_proxies.has(peer_id):
        return
    if is_instance_valid(remote_player_proxies[peer_id]):
        remote_player_proxies[peer_id].call_deferred("queue_free")
    remote_player_proxies.erase(peer_id)


func _clear_remote_player_proxies() -> void:
    for peer_id in remote_player_proxies.keys().duplicate():
        _remove_remote_player_proxy(int(peer_id))


func _update_remote_break_outline(peer_id: int, same_dimension: bool, state: Dictionary) -> void:
    if not same_dimension or not bool(state.get("breaking", false)):
        _remove_remote_break_outline(peer_id)
        return

    var block_id: int = int(state.get("break_block_id", 0))
    if block_id <= 0:
        _remove_remote_break_outline(peer_id)
        return

    var block = ItemMap.map(block_id)
    if block == null:
        _remove_remote_break_outline(peer_id)
        return

    var outline = _ensure_remote_break_outline(peer_id)
    if outline == null:
        return

    outline.global_position = Vector3(state.get("break_position", Vector3i.ZERO)) + Vector3(0.5, 0.5, 0.5)
    outline.update_block(block)
    outline.update_progress(clampf(float(state.get("break_progress", 0.0)), 0.0, 1.0))


func _ensure_remote_break_outline(peer_id: int):
    if remote_break_outlines.has(peer_id) and is_instance_valid(remote_break_outlines[peer_id]):
        return remote_break_outlines[peer_id]

    var scene = load(BREAK_OUTLINE_SCENE_PATH)
    if not (scene is PackedScene):
        return null

    var outline = scene.instantiate()
    get_tree().get_root().add_child(outline)
    remote_break_outlines[peer_id] = outline
    return outline


func _remove_remote_break_outline(peer_id: int) -> void:
    if not remote_break_outlines.has(peer_id):
        return
    if is_instance_valid(remote_break_outlines[peer_id]):
        remote_break_outlines[peer_id].call_deferred("queue_free")
    remote_break_outlines.erase(peer_id)


func _clear_remote_break_outlines() -> void:
    for peer_id in remote_break_outlines.keys():
        if is_instance_valid(remote_break_outlines[peer_id]):
            remote_break_outlines[peer_id].call_deferred("queue_free")
    remote_break_outlines.clear()


func _build_hud() -> void:
    hud = CanvasLayer.new()
    hud.layer = 64
    add_child(hud)

    overlay = Control.new()
    overlay.anchor_right = 1.0
    overlay.anchor_bottom = 1.0
    overlay.offset_left = 0.0
    overlay.offset_top = 0.0
    overlay.offset_right = 0.0
    overlay.offset_bottom = 0.0
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(overlay)

    death_overlay = Control.new()
    death_overlay.visible = false
    death_overlay.anchor_right = 1.0
    death_overlay.anchor_bottom = 1.0
    death_overlay.offset_right = 0.0
    death_overlay.offset_bottom = 0.0
    death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(death_overlay)

    var death_fade := ColorRect.new()
    death_fade.anchor_right = 1.0
    death_fade.anchor_bottom = 1.0
    death_fade.offset_right = 0.0
    death_fade.offset_bottom = 0.0
    death_fade.color = Color(0.12, 0.0, 0.0, 0.55)
    death_overlay.add_child(death_fade)

    var death_center := CenterContainer.new()
    death_center.anchor_right = 1.0
    death_center.anchor_bottom = 1.0
    death_center.offset_right = 0.0
    death_center.offset_bottom = 0.0
    death_overlay.add_child(death_center)

    var death_panel := PanelContainer.new()
    death_panel.custom_minimum_size = Vector2(260.0, 92.0)
    death_center.add_child(death_panel)

    var death_margin := MarginContainer.new()
    death_margin.add_theme_constant_override("margin_left", 16)
    death_margin.add_theme_constant_override("margin_right", 16)
    death_margin.add_theme_constant_override("margin_top", 14)
    death_margin.add_theme_constant_override("margin_bottom", 14)
    death_panel.add_child(death_margin)

    var death_column := VBoxContainer.new()
    death_column.alignment = BoxContainer.ALIGNMENT_CENTER
    death_column.add_theme_constant_override("separation", 6)
    death_margin.add_child(death_column)

    death_overlay_title = Label.new()
    death_overlay_title.text = "YOU DIED"
    death_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    death_overlay_title.add_theme_font_size_override("font_size", 24)
    death_overlay_title.add_theme_color_override("font_color", Color(0.94, 0.42, 0.42))
    death_column.add_child(death_overlay_title)

    death_overlay_subtitle = Label.new()
    death_overlay_subtitle.text = "Respawning..."
    death_overlay_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    death_overlay_subtitle.add_theme_font_size_override("font_size", 11)
    death_column.add_child(death_overlay_subtitle)

    revive_prompt_label = Label.new()
    revive_prompt_label.visible = false
    revive_prompt_label.anchor_left = 0.5
    revive_prompt_label.anchor_top = 1.0
    revive_prompt_label.anchor_right = 0.5
    revive_prompt_label.anchor_bottom = 1.0
    revive_prompt_label.offset_left = -190.0
    revive_prompt_label.offset_top = -86.0
    revive_prompt_label.offset_right = 190.0
    revive_prompt_label.offset_bottom = -48.0
    revive_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    revive_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    revive_prompt_label.add_theme_font_size_override("font_size", 14)
    revive_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.86))
    revive_prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
    revive_prompt_label.add_theme_constant_override("shadow_outline_size", 6)
    overlay.add_child(revive_prompt_label)

    reconnect_overlay = Control.new()
    reconnect_overlay.visible = false
    reconnect_overlay.anchor_right = 1.0
    reconnect_overlay.anchor_bottom = 1.0
    reconnect_overlay.offset_right = 0.0
    reconnect_overlay.offset_bottom = 0.0
    reconnect_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.add_child(reconnect_overlay)

    var reconnect_fade := ColorRect.new()
    reconnect_fade.anchor_right = 1.0
    reconnect_fade.anchor_bottom = 1.0
    reconnect_fade.offset_right = 0.0
    reconnect_fade.offset_bottom = 0.0
    reconnect_fade.color = Color(0.0, 0.02, 0.05, 0.58)
    reconnect_overlay.add_child(reconnect_fade)

    var reconnect_center := CenterContainer.new()
    reconnect_center.anchor_right = 1.0
    reconnect_center.anchor_bottom = 1.0
    reconnect_center.offset_right = 0.0
    reconnect_center.offset_bottom = 0.0
    reconnect_overlay.add_child(reconnect_center)

    var reconnect_panel := PanelContainer.new()
    reconnect_panel.custom_minimum_size = Vector2(320.0, 128.0)
    reconnect_center.add_child(reconnect_panel)

    var reconnect_margin := MarginContainer.new()
    reconnect_margin.add_theme_constant_override("margin_left", 16)
    reconnect_margin.add_theme_constant_override("margin_right", 16)
    reconnect_margin.add_theme_constant_override("margin_top", 14)
    reconnect_margin.add_theme_constant_override("margin_bottom", 14)
    reconnect_panel.add_child(reconnect_margin)

    var reconnect_column := VBoxContainer.new()
    reconnect_column.alignment = BoxContainer.ALIGNMENT_CENTER
    reconnect_column.add_theme_constant_override("separation", 8)
    reconnect_margin.add_child(reconnect_column)

    reconnect_overlay_title = Label.new()
    reconnect_overlay_title.text = "CONNECTION LOST"
    reconnect_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    reconnect_overlay_title.add_theme_font_size_override("font_size", 20)
    reconnect_overlay_title.add_theme_color_override("font_color", Color(0.92, 0.92, 0.96))
    reconnect_column.add_child(reconnect_overlay_title)

    reconnect_overlay_subtitle = Label.new()
    reconnect_overlay_subtitle.text = "Reconnecting..."
    reconnect_overlay_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    reconnect_overlay_subtitle.add_theme_font_size_override("font_size", 11)
    reconnect_column.add_child(reconnect_overlay_subtitle)

    var reconnect_buttons := HBoxContainer.new()
    reconnect_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    reconnect_buttons.add_theme_constant_override("separation", 8)
    reconnect_column.add_child(reconnect_buttons)

    var reconnect_button := Button.new()
    reconnect_button.text = "Reconnect"
    reconnect_button.custom_minimum_size = Vector2(96, 0)
    reconnect_button.pressed.connect(_attempt_reconnect)
    reconnect_buttons.add_child(reconnect_button)

    var leave_button := Button.new()
    leave_button.text = "Leave"
    leave_button.custom_minimum_size = Vector2(96, 0)
    leave_button.pressed.connect(_leave_reconnect_to_menu)
    reconnect_buttons.add_child(leave_button)

    panel = PanelContainer.new()
    panel.visible = false
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.anchor_top = 0.0
    panel.anchor_bottom = 0.0
    panel.offset_left = -PANEL_WIDTH * 0.5
    panel.offset_right = PANEL_WIDTH * 0.5
    panel.offset_top = 12
    panel.offset_bottom = 156
    panel.clip_contents = false
    overlay.add_child(panel)

    panel_scroll = ScrollContainer.new()
    panel_scroll.anchor_right = 1.0
    panel_scroll.anchor_bottom = 1.0
    panel_scroll.offset_right = 0.0
    panel_scroll.offset_bottom = 0.0
    panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel_scroll.follow_focus = true
    panel.add_child(panel_scroll)

    var outer_margin: MarginContainer = MarginContainer.new()
    outer_margin.add_theme_constant_override("margin_left", 8)
    outer_margin.add_theme_constant_override("margin_right", 8)
    outer_margin.add_theme_constant_override("margin_top", 8)
    outer_margin.add_theme_constant_override("margin_bottom", 8)
    panel_scroll.add_child(outer_margin)

    panel_column = VBoxContainer.new()
    panel_column.add_theme_constant_override("separation", 6)
    outer_margin.add_child(panel_column)

    var title_row: HBoxContainer = HBoxContainer.new()
    title_row.add_theme_constant_override("separation", 6)
    panel_column.add_child(title_row)

    var title: Label = Label.new()
    title.text = "Co-op LAN"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 13)
    title_row.add_child(title)

    var close_button: Button = Button.new()
    close_button.text = "x"
    close_button.custom_minimum_size = Vector2(24, 0)
    close_button.add_theme_font_size_override("font_size", 10)
    close_button.pressed.connect(toggle_panel.bind(false))
    title_row.add_child(close_button)

    local_ip_label = Label.new()
    local_ip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    local_ip_label.add_theme_font_size_override("font_size", 9)
    panel_column.add_child(local_ip_label)

    var join_row: HBoxContainer = HBoxContainer.new()
    join_row.add_theme_constant_override("separation", 6)
    panel_column.add_child(join_row)

    var ip_title: Label = Label.new()
    ip_title.text = "IP"
    ip_title.custom_minimum_size = Vector2(18, 0)
    ip_title.add_theme_font_size_override("font_size", 10)
    join_row.add_child(ip_title)

    address_input = LineEdit.new()
    address_input.placeholder_text = "192.168.x.x"
    address_input.text = str(config.get("address", "127.0.0.1"))
    address_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    address_input.custom_minimum_size = Vector2(0, 22)
    address_input.add_theme_font_size_override("font_size", 10)
    address_input.text_changed.connect(_on_address_changed)
    address_input.text_submitted.connect(_on_join_text_submitted)
    join_row.add_child(address_input)

    var port_title: Label = Label.new()
    port_title.text = "Port"
    port_title.custom_minimum_size = Vector2(28, 0)
    port_title.add_theme_font_size_override("font_size", 10)
    join_row.add_child(port_title)

    port_input = SpinBox.new()
    port_input.min_value = 1
    port_input.max_value = 65535
    port_input.step = 1
    port_input.rounded = true
    port_input.custom_minimum_size = Vector2(72, 22)
    port_input.add_theme_font_size_override("font_size", 10)
    port_input.value = int(config.get("port", DEFAULT_PORT))
    port_input.value_changed.connect(_on_port_changed)
    join_row.add_child(port_input)

    var button_row: HBoxContainer = HBoxContainer.new()
    button_row.add_theme_constant_override("separation", 6)
    panel_column.add_child(button_row)

    var host_button: Button = Button.new()
    host_button.text = "Host"
    host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    host_button.add_theme_font_size_override("font_size", 10)
    host_button.pressed.connect(host_session)
    button_row.add_child(host_button)

    var join_button: Button = Button.new()
    join_button.text = "Join"
    join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    join_button.add_theme_font_size_override("font_size", 10)
    join_button.pressed.connect(join_session)
    button_row.add_child(join_button)

    var disconnect_button: Button = Button.new()
    disconnect_button.text = "Leave"
    disconnect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    disconnect_button.add_theme_font_size_override("font_size", 10)
    disconnect_button.pressed.connect(leave_session)
    button_row.add_child(disconnect_button)

    var chat_hint_label: Label = Label.new()
    chat_hint_label.text = "Slash chat: `/`  |  Spawn browser: `F10`"
    chat_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    chat_hint_label.add_theme_font_size_override("font_size", 9)
    panel_column.add_child(chat_hint_label)

    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.custom_minimum_size = Vector2(0, 34)
    status_label.add_theme_font_size_override("font_size", 10)
    panel_column.add_child(status_label)

    _refresh_local_ip_label()
    _sync_inputs_from_config()

    spawn_browser_overlay = Control.new()
    spawn_browser_overlay.visible = false
    spawn_browser_overlay.anchor_right = 1.0
    spawn_browser_overlay.anchor_bottom = 1.0
    spawn_browser_overlay.offset_right = 0.0
    spawn_browser_overlay.offset_bottom = 0.0
    spawn_browser_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.add_child(spawn_browser_overlay)

    var spawn_browser_fade := ColorRect.new()
    spawn_browser_fade.anchor_right = 1.0
    spawn_browser_fade.anchor_bottom = 1.0
    spawn_browser_fade.offset_right = 0.0
    spawn_browser_fade.offset_bottom = 0.0
    spawn_browser_fade.color = Color(0.0, 0.0, 0.0, 0.55)
    spawn_browser_overlay.add_child(spawn_browser_fade)

    var spawn_browser_center := CenterContainer.new()
    spawn_browser_center.anchor_right = 1.0
    spawn_browser_center.anchor_bottom = 1.0
    spawn_browser_center.offset_right = 0.0
    spawn_browser_center.offset_bottom = 0.0
    spawn_browser_overlay.add_child(spawn_browser_center)

    spawn_browser_panel = PanelContainer.new()
    spawn_browser_panel.custom_minimum_size = Vector2(420.0, 420.0)
    spawn_browser_center.add_child(spawn_browser_panel)

    var spawn_browser_margin := MarginContainer.new()
    spawn_browser_margin.add_theme_constant_override("margin_left", 12)
    spawn_browser_margin.add_theme_constant_override("margin_right", 12)
    spawn_browser_margin.add_theme_constant_override("margin_top", 12)
    spawn_browser_margin.add_theme_constant_override("margin_bottom", 12)
    spawn_browser_panel.add_child(spawn_browser_margin)

    var spawn_browser_column := VBoxContainer.new()
    spawn_browser_column.add_theme_constant_override("separation", 8)
    spawn_browser_margin.add_child(spawn_browser_column)

    var spawn_browser_title_row := HBoxContainer.new()
    spawn_browser_title_row.add_theme_constant_override("separation", 6)
    spawn_browser_column.add_child(spawn_browser_title_row)

    var spawn_browser_title := Label.new()
    spawn_browser_title.text = "Mob Spawn Browser"
    spawn_browser_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spawn_browser_title.add_theme_font_size_override("font_size", 16)
    spawn_browser_title_row.add_child(spawn_browser_title)

    var spawn_browser_close_button := Button.new()
    spawn_browser_close_button.text = "x"
    spawn_browser_close_button.custom_minimum_size = Vector2(28, 0)
    spawn_browser_close_button.pressed.connect(toggle_spawn_browser.bind(false, ""))
    spawn_browser_title_row.add_child(spawn_browser_close_button)

    spawn_browser_search_input = LineEdit.new()
    spawn_browser_search_input.placeholder_text = "Search mobs..."
    spawn_browser_search_input.text_changed.connect(_on_spawn_browser_search_changed)
    spawn_browser_search_input.text_submitted.connect(_on_spawn_browser_search_submitted)
    spawn_browser_column.add_child(spawn_browser_search_input)

    spawn_browser_hint_label = Label.new()
    spawn_browser_hint_label.text = "Type to filter, Enter to spawn, Esc to close"
    spawn_browser_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    spawn_browser_hint_label.add_theme_font_size_override("font_size", 10)
    spawn_browser_column.add_child(spawn_browser_hint_label)

    spawn_browser_list = ItemList.new()
    spawn_browser_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    spawn_browser_list.allow_reselect = true
    spawn_browser_list.item_selected.connect(_on_spawn_browser_item_selected)
    spawn_browser_list.item_activated.connect(_on_spawn_browser_item_activated)
    spawn_browser_column.add_child(spawn_browser_list)

    var spawn_browser_button_row := HBoxContainer.new()
    spawn_browser_button_row.add_theme_constant_override("separation", 8)
    spawn_browser_column.add_child(spawn_browser_button_row)

    var spawn_browser_spawn_button := Button.new()
    spawn_browser_spawn_button.text = "Spawn"
    spawn_browser_spawn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spawn_browser_spawn_button.pressed.connect(_spawn_from_browser_selection)
    spawn_browser_button_row.add_child(spawn_browser_spawn_button)

    var spawn_browser_cancel_button := Button.new()
    spawn_browser_cancel_button.text = "Close"
    spawn_browser_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spawn_browser_cancel_button.pressed.connect(toggle_spawn_browser.bind(false, ""))
    spawn_browser_button_row.add_child(spawn_browser_cancel_button)

    _refresh_spawn_browser_entries("")


func _refresh_local_ip_label() -> void:
    if local_ip_label == null:
        return

    var best_ip: String = _get_best_local_ipv4()
    local_ip_label.text = "LAN: %s" % best_ip


func _get_best_local_ipv4() -> String:
    var best_ip: String = "127.0.0.1"
    var best_score: int = 999

    for address in IP.get_local_addresses():
        if ":" in address:
            continue
        if address.begins_with("127."):
            continue

        var score: int = _score_ipv4(address)
        if score < best_score:
            best_score = score
            best_ip = address

    return best_ip


func _score_ipv4(address: String) -> int:
    if address.begins_with("192.168."):
        return 0
    if address.begins_with("10."):
        return 1
    if address.begins_with("172."):
        var second_octet_text: String = address.get_slice(".", 1)
        var second_octet: int = int(second_octet_text)
        if second_octet >= 16 and second_octet <= 31:
            if second_octet == 17 or second_octet == 18:
                return 4
            return 2
    if address.begins_with("100."):
        return 3
    return 5


func _sync_inputs_from_config() -> void:
    if address_input != null:
        address_input.text = str(config.get("address", "127.0.0.1"))
    if port_input != null:
        port_input.value = int(config.get("port", DEFAULT_PORT))


func _apply_ui_to_config() -> void:
    var normalized_address: String = str(config.get("address", "127.0.0.1"))
    var normalized_port: int = int(config.get("port", DEFAULT_PORT))

    if address_input != null:
        var address: String = address_input.text.strip_edges()
        normalized_address = address if address != "" else "127.0.0.1"
    if port_input != null:
        normalized_port = clampi(int(port_input.value), 1, 65535)

    config["address"] = normalized_address
    config["port"] = normalized_port
    _save_config()

    if address_input != null and address_input.text != normalized_address:
        address_input.text = normalized_address
    if port_input != null and int(port_input.value) != normalized_port:
        port_input.value = normalized_port


func _on_address_changed(_new_text: String) -> void:
    _apply_ui_to_config()
    _update_status_text()


func _on_join_text_submitted(_new_text: String) -> void:
    join_session()


func _on_port_changed(_new_value: float) -> void:
    _apply_ui_to_config()
    _update_status_text()


func toggle_spawn_browser(force_visible: Variant = null, initial_query: String = "") -> void:
    if spawn_browser_overlay == null:
        return

    var next_visible: bool = not spawn_browser_overlay.visible if force_visible == null else bool(force_visible)
    if next_visible == spawn_browser_overlay.visible and (not next_visible or initial_query == ""):
        return

    if next_visible:
        if panel_visible:
            toggle_panel(false)
        spawn_browser_restore_capture_on_close = MouseHandler.captured
        MouseHandler.release()
        if is_instance_valid(Ref.player):
            Ref.player.consume_actions()
        spawn_browser_overlay.visible = true
        _refresh_overlay_layout()
        if spawn_browser_search_input != null:
            spawn_browser_search_input.text = initial_query
            spawn_browser_search_input.grab_focus()
            spawn_browser_search_input.caret_column = spawn_browser_search_input.text.length()
        _refresh_spawn_browser_entries(initial_query)
        return

    spawn_browser_overlay.visible = false
    if spawn_browser_search_input != null:
        spawn_browser_search_input.text = ""
    if is_instance_valid(Ref.player):
        Ref.player.consume_actions()
    if spawn_browser_restore_capture_on_close and not panel_visible:
        MouseHandler.capture()
    spawn_browser_restore_capture_on_close = false


func _refresh_spawn_browser_entries(filter_text: String) -> void:
    if spawn_browser_list == null:
        return

    spawn_browser_entries = PackedStringArray()
    spawn_browser_list.clear()
    var lowered_filter: String = _normalize_debug_spawn_id(filter_text)
    for spawn_id in _get_debug_spawn_ids():
        var spawn_text: String = str(spawn_id)
        if lowered_filter != "" and not spawn_text.contains(lowered_filter):
            continue
        spawn_browser_entries.append(spawn_text)
        spawn_browser_list.add_item(spawn_text)

    if spawn_browser_hint_label != null:
        spawn_browser_hint_label.text = "%d mobs available - Enter or double click to spawn" % spawn_browser_entries.size() if not spawn_browser_entries.is_empty() else "No mobs match that filter"

    if not spawn_browser_entries.is_empty():
        spawn_browser_list.select(0)


func _get_selected_spawn_browser_id() -> String:
    if spawn_browser_list == null or spawn_browser_entries.is_empty():
        return ""
    var selected_items: PackedInt32Array = spawn_browser_list.get_selected_items()
    if selected_items.is_empty():
        return str(spawn_browser_entries[0])
    var selected_index: int = int(selected_items[0])
    if selected_index < 0 or selected_index >= spawn_browser_entries.size():
        return ""
    return str(spawn_browser_entries[selected_index])


func _spawn_from_browser_selection(_pressed: bool = false) -> void:
    var spawn_id: String = _get_selected_spawn_browser_id()
    if spawn_id == "":
        status_message = "No mob selected"
        _update_status_text()
        return
    _execute_spawn_command(PackedStringArray(["/spawn", spawn_id]))


func _on_spawn_browser_search_changed(new_text: String) -> void:
    _refresh_spawn_browser_entries(new_text)


func _on_spawn_browser_search_submitted(_text: String) -> void:
    _spawn_from_browser_selection()


func _on_spawn_browser_item_selected(index: int) -> void:
    if spawn_browser_hint_label == null or index < 0 or index >= spawn_browser_entries.size():
        return
    spawn_browser_hint_label.text = "Ready to spawn `%s`" % str(spawn_browser_entries[index])


func _on_spawn_browser_item_activated(_index: int) -> void:
    _spawn_from_browser_selection()


func _update_status_text() -> void:
    if status_label == null:
        return

    var mode: String = "offline"
    if _has_live_peer():
        mode = "host" if multiplayer.is_server() else "client"

    var peers: int = peer_states.size()
    if peer_states.has(multiplayer.get_unique_id()):
        peers -= 1
    peers = max(peers, 0)

    status_label.text = "%s\nMode: %s  |  Peers: %s" % [status_message, mode, peers]



func _load_config(announce: bool = false) -> void:
    config = {
        "address": "127.0.0.1",
        "port": DEFAULT_PORT,
        "avatar_id": DEFAULT_AVATAR_ID,
    }

    if not FileAccess.file_exists(CONFIG_PATH):
        _save_config()
        if announce:
            status_message = "Created config at %s" % OS.get_user_data_dir().path_join("lucid_blocks_coop_config.json")
            _sync_inputs_from_config()
            _update_status_text()
        return

    var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
    if file == null:
        return

    var data: Variant = JSON.parse_string(file.get_as_text())
    if data is Dictionary:
        config.merge(data, true)
    config["avatar_id"] = _normalize_avatar_id(str(config.get("avatar_id", DEFAULT_AVATAR_ID)))

    _sync_inputs_from_config()
    _refresh_local_ip_label()

    if announce:
        status_message = "Reloaded config"
        print("[lucid-blocks-coop] reloaded config: %s" % config)
        _update_status_text()


func _save_config() -> void:
    var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
    if file == null:
        return
    file.store_string(JSON.stringify(config, "  "))


func _on_peer_connected(id: int) -> void:
    status_message = "Peer %s connected" % id
    print("[lucid-blocks-coop] %s" % status_message)
    _update_status_text()
    _refresh_host_entity_activity_override(999.0)


func _on_peer_disconnected(id: int) -> void:
    peer_states.erase(id)
    if markers.has(id):
        markers[id].call_deferred("queue_free")
        markers.erase(id)
    _remove_remote_player_proxy(id)
    _remove_remote_break_outline(id)
    status_message = "Peer %s disconnected" % id
    print("[lucid-blocks-coop] %s" % status_message)
    _update_status_text()
    if local_downed and not _has_same_instance_reviver_available(multiplayer.get_unique_id()):
        _commit_local_real_death("Your partner disconnected")


func _on_connected_to_server() -> void:
    guest_persistent_ready = false
    _install_player_death_hook()
    _mark_host_contact()
    status_message = "Connected as peer %s, waiting for host world" % multiplayer.get_unique_id()
    print("[lucid-blocks-coop] %s" % status_message)
    _update_status_text()
    request_host_world_snapshot.rpc_id(1)


func _on_connection_failed() -> void:
    if reconnect_pending:
        disconnect_session(false)
        client_restore_in_progress = true
        if _can_sample_player():
            _reset_local_player_motion()
            Ref.player.disabled = true
        local_quit_in_progress = false
        status_message = "Reconnect failed"
        _update_status_text()
        reconnect_retry_timer = AUTO_RECONNECT_INTERVAL
        _set_reconnect_overlay_visible(true)
        return

    disconnect_session(false)
    local_quit_in_progress = false
    status_message = "Connection failed"
    push_warning("[lucid-blocks-coop] connection failed")
    _update_status_text()


func _on_local_game_quit() -> void:
    if suppress_local_game_quit_session_shutdown:
        return

    if multiplayer.is_server() and is_local_player_fake_dead():
        _abort_host_respawn(false, false)

    clear_fake_death_override_after_shutdown = false
    local_quit_in_progress = true
    if not _has_live_peer():
        return

    if multiplayer.is_server():
        host_rehost_pending = false
        _shutdown_host_session.call_deferred(false, "Host left the session")
    else:
        if guest_persistent_ready:
            _send_persistent_state_to_host(true)
        disconnect_session(false)


func _on_server_disconnected() -> void:
    if local_quit_in_progress:
        disconnect_session(false)
        status_message = "Server disconnected"
        print("[lucid-blocks-coop] %s" % status_message)
        _update_status_text()
        return

    _begin_reconnect_flow("Server disconnected")


func _shutdown_host_session(reconnectable: bool, reason: String = "") -> void:
    if not _has_live_peer() or not multiplayer.is_server():
        return

    host_session_ending.rpc(reconnectable, reason)
    await get_tree().create_timer(0.25, true).timeout
    disconnect_session(false)
    if clear_fake_death_override_after_shutdown:
        local_fake_death_save_override.clear()
        local_fake_death_respawn_target_valid = false
        clear_fake_death_override_after_shutdown = false
    if not reconnectable:
        local_quit_in_progress = false


func _on_local_world_loaded() -> void:
    if not host_rehost_pending:
        return
    _resume_host_session_after_world_load.call_deferred()


func _resume_host_session_after_world_load() -> void:
    if not host_rehost_pending or _has_live_peer():
        return

    for attempt in range(50):
        await get_tree().create_timer(0.1, true).timeout
        if not host_rehost_pending or _has_live_peer():
            return
        if _can_share_loaded_world():
            break

    if not host_rehost_pending or _has_live_peer() or not _can_share_loaded_world():
        host_rehost_pending = false
        return

    config["port"] = host_rehost_port
    _sync_inputs_from_config()
    status_message = "Rehosting on port %s" % host_rehost_port
    _update_status_text()
    _install_player_death_hook()
    host_session()
    if multiplayer.is_server():
        host_rehost_pending = false


@rpc("authority", "call_remote", "reliable")
func host_session_ending(reconnectable: bool = false, reason: String = "") -> void:
    if multiplayer.is_server():
        return

    if reconnectable:
        local_quit_in_progress = false
        _begin_reconnect_flow(reason if reason != "" else "Host is rehosting")
        return

    local_quit_in_progress = true
    if guest_persistent_ready:
        _send_persistent_state_to_host(true)
    disconnect_session(false)
    status_message = reason if reason != "" else "Host ended the session"
    _update_status_text()
    _queue_client_main_menu_kick()


func _queue_client_main_menu_kick() -> void:
    if multiplayer.is_server() or client_menu_kick_pending:
        return
    client_menu_kick_pending = true
    _kick_client_to_main_menu.call_deferred()


func _begin_reconnect_flow(reason: String) -> void:
    if multiplayer.is_server() or local_quit_in_progress:
        return
    if local_downed:
        disconnect_session(false)
        return

    _close_pause_menu_if_open()
    disconnect_session(false)
    reconnect_pending = true
    client_restore_in_progress = true
    reconnect_attempt_count = 0
    reconnect_retry_timer = AUTO_RECONNECT_INTERVAL
    reconnect_reason = reason
    status_message = reason
    _update_status_text()
    _set_reconnect_overlay_visible(true)
    if _can_sample_player():
        _reset_local_player_motion()
        Ref.player.disabled = true


func _tick_reconnect(delta: float) -> void:
    if multiplayer.is_server() or _has_live_peer() or receiving_host_world:
        return

    reconnect_retry_timer = maxf(0.0, reconnect_retry_timer - delta)
    if reconnect_overlay_subtitle != null:
        reconnect_overlay_subtitle.text = "%s\nRetrying in %.1fs (attempt %d)" % [
            reconnect_reason,
            reconnect_retry_timer,
            reconnect_attempt_count + 1,
        ]

    if reconnect_retry_timer > 0.0:
        return
    _attempt_reconnect()


func _attempt_reconnect() -> void:
    if multiplayer.is_server() or _has_live_peer() or receiving_host_world:
        return

    _close_pause_menu_if_open()
    reconnect_pending = true
    client_restore_in_progress = true
    reconnect_attempt_count += 1
    reconnect_retry_timer = AUTO_RECONNECT_INTERVAL
    local_quit_in_progress = false
    guest_persistent_ready = false
    last_host_contact_time = 0
    client_state_heartbeat_timer = 0.0
    last_sent_client_state_hash = 0

    var address: String = str(config.get("address", "127.0.0.1")).strip_edges()
    var port: int = int(config.get("port", DEFAULT_PORT))
    var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
    var err: Error = peer.create_client(address, port)
    if err != OK:
        status_message = "Reconnect failed (%s)" % err
        _update_status_text()
        _set_reconnect_overlay_visible(true)
        return

    multiplayer.multiplayer_peer = peer
    peer_states.clear()
    status_message = "Reconnecting to %s:%s" % [address, port]
    _update_status_text()
    _set_reconnect_overlay_visible(true)


func _leave_reconnect_to_menu() -> void:
    leave_session()


func _set_reconnect_overlay_visible(visible: bool) -> void:
    if reconnect_overlay == null:
        return
    if visible:
        _close_pause_menu_if_open()
        if panel_visible:
            restore_capture_on_close = false
            toggle_panel(false)
        reconnect_restore_capture_on_close = MouseHandler.captured
        MouseHandler.release()
    elif reconnect_restore_capture_on_close and not panel_visible:
        MouseHandler.capture()
        reconnect_restore_capture_on_close = false
    reconnect_overlay.visible = visible
    if visible and reconnect_overlay_title != null:
        reconnect_overlay_title.text = "RECONNECTING"


func _kick_client_to_main_menu() -> void:
    if multiplayer.is_server() or not is_instance_valid(Ref.main) or not Ref.main.loaded:
        client_restore_in_progress = false
        client_menu_kick_pending = false
        return

    _close_pause_menu_if_open()
    await Ref.trans.open()
    Ref.audio_manager.play_song(Ref.main.main_menu_music, 100)

    var main_menu = Ref.main.get_node_or_null("%MainMenu")
    var game_menu = Ref.main.get_node_or_null("%GameMenu")
    if main_menu != null:
        main_menu.open()
    if game_menu != null:
        game_menu.close()

    await Ref.main.quit_game(false, false)
    await Ref.trans.close()

    if main_menu != null:
        main_menu.activate()
    local_quit_in_progress = false
    client_restore_in_progress = false
    client_menu_kick_pending = false
    host_rehost_pending = false


func _teleport_local_player_near(target_position: Vector3) -> void:
    if not _can_sample_player():
        return

    _teleport_local_player_exact(_resolve_safe_position_near_player(target_position))
    if _has_live_peer():
        _broadcast_local_state_now()


func _send_world_snapshot_to_peer(peer_id: int, target_dimension: int = -1, target_pocket_owner_key: String = "", follow_host_position: bool = true) -> void:
    if not _can_share_loaded_world():
        return

    status_message = "Sending world to peer %s" % peer_id
    _update_status_text()

    # Do not force a full save here; it stalls join badly.
    # We snapshot the current in-memory loaded world/register state instead.

    var register_data: Dictionary = Ref.save_file_manager.loaded_file_register.data.duplicate_deep()
    var actual_dimension: int = target_dimension if target_dimension >= 0 else int(Ref.world.current_dimension)
    register_data["dimension"] = actual_dimension
    register_data["pocket_owner_key"] = target_pocket_owner_key if actual_dimension == int(LucidBlocksWorld.Dimension.POCKET) else ""

    var register_json: String = JSON.stringify(JSON.from_native(register_data))
    var save_json: String = JSON.stringify(JSON.from_native(Ref.save_file_manager.loaded_file.data))
    var save_buffer: PackedByteArray = save_json.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
    var chunk_count: int = maxi(1, int(ceil(float(save_buffer.size()) / float(SNAPSHOT_CHUNK_SIZE))))

    begin_host_world_snapshot.rpc_id(peer_id, register_json, chunk_count, Ref.player.global_position, follow_host_position)
    for chunk_index in range(chunk_count):
        var start: int = chunk_index * SNAPSHOT_CHUNK_SIZE
        var end: int = mini(start + SNAPSHOT_CHUNK_SIZE, save_buffer.size())
        host_world_snapshot_chunk.rpc_id(peer_id, chunk_index, save_buffer.slice(start, end))
    finish_host_world_snapshot.rpc_id(peer_id)

    status_message = "Peer %s joined host world" % peer_id
    _update_status_text()


func _apply_received_host_world() -> void:
    if incoming_snapshot_register_json == "":
        receiving_host_world = false
        return

    for chunk_index in range(incoming_snapshot_chunk_count):
        if not incoming_snapshot_chunks.has(chunk_index):
            _handle_host_world_snapshot_failure("Missing world chunk %s" % chunk_index)
            return

    var compressed_buffer: PackedByteArray = PackedByteArray()
    for chunk_index in range(incoming_snapshot_chunk_count):
        compressed_buffer.append_array(incoming_snapshot_chunks[chunk_index])

    var save_json: String = compressed_buffer.decompress_dynamic(4000000000, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
    var register_parse: Variant = JSON.parse_string(incoming_snapshot_register_json)
    var save_parse: Variant = JSON.parse_string(save_json)
    if not (register_parse is Dictionary) or not (save_parse is Dictionary):
        _handle_host_world_snapshot_failure("Failed to parse host world")
        return

    await _load_host_world_snapshot(JSON.to_native(register_parse), JSON.to_native(save_parse), incoming_snapshot_host_position)


func _handle_host_world_snapshot_failure(reason: String) -> void:
    receiving_host_world = false
    client_restore_in_progress = false
    status_message = reason
    _update_status_text()
    if not multiplayer.is_server() and _has_live_peer() and not local_quit_in_progress:
        _begin_reconnect_flow(reason)


func _load_host_world_snapshot(register_data: Dictionary, save_data: Dictionary, host_position: Vector3) -> void:
    receiving_host_world = true
    client_restore_in_progress = true
    local_fake_death_pending = false
    local_fake_death_save_override.clear()
    local_fake_death_respawn_target_valid = false
    clear_fake_death_override_after_shutdown = false
    host_respawning = false
    remote_host_respawning = false
    status_message = "Loading host world"
    _update_status_text()

    await Ref.trans.open()

    if Ref.world.load_enabled:
        suppress_local_game_quit_session_shutdown = true
        await Ref.main.quit_game(false, false)
        suppress_local_game_quit_session_shutdown = false

    var register: SaveFileRegister = SaveFileRegister.new()
    register.is_dimensional = false
    register.data = register_data.duplicate_deep()

    var save_file: SaveFile = SaveFile.new()
    save_file.data = save_data.duplicate_deep()

    Ref.save_file_manager.loaded_file_register = register
    Ref.save_file_manager.loaded_file = save_file
    Ref.audio_manager.stop_song(Ref.main.main_menu_music)
    Ref.save_file_manager.load_file(register, false)

    await Ref.main.enter_game()
    client_world_sync_ready = false
    guest_persistent_ready = false
    _install_player_death_hook()
    _prepare_client_world_sync()
    if is_instance_valid(Ref.player):
        Ref.player.disabled = true
    if incoming_snapshot_follow_host_position:
        _teleport_local_player_near(host_position)
    if not multiplayer.is_server() and _has_live_peer():
        status_message = "Restoring character"
        _update_status_text()
        request_guest_persistent_state.rpc_id(1, _get_local_player_key(), _get_local_player_name())

    receiving_host_world = false


func _install_player_death_hook() -> void:
    if not is_instance_valid(Ref.player) or not is_instance_valid(Ref.main):
        coop_player_death_hooked = false
        coop_player_death_hooked_instance_id = 0
        return

    var coop_handler := Callable(self, "_on_player_died_for_coop")
    if coop_player_death_hooked and coop_player_death_hooked_instance_id == Ref.player.get_instance_id() and Ref.player.died.is_connected(coop_handler):
        return

    var original_handler := Callable(Ref.main, "_on_player_death")
    if Ref.player.died.is_connected(original_handler):
        Ref.player.died.disconnect(original_handler)
    if not Ref.player.died.is_connected(coop_handler):
        Ref.player.died.connect(coop_handler)
    coop_player_death_hooked = true
    coop_player_death_hooked_instance_id = Ref.player.get_instance_id()


func _on_player_died_for_coop() -> void:
    if not _has_live_peer():
        _restore_original_death_handler()
        if is_instance_valid(Ref.main):
            Ref.main.player_death.call_deferred()
        return

    _enter_local_downed_state()


func _restore_original_death_handler() -> void:
    if not coop_player_death_hooked:
        return
    if not is_instance_valid(Ref.player) or not is_instance_valid(Ref.main):
        coop_player_death_hooked = false
        coop_player_death_hooked_instance_id = 0
        return

    var coop_handler := Callable(self, "_on_player_died_for_coop")
    var original_handler := Callable(Ref.main, "_on_player_death")

    if Ref.player.died.is_connected(coop_handler):
        Ref.player.died.disconnect(coop_handler)
    if not Ref.player.died.is_connected(original_handler):
        Ref.player.died.connect(original_handler)
    coop_player_death_hooked = false
    coop_player_death_hooked_instance_id = 0


func _handle_host_player_death() -> void:
    if not local_fake_death_pending and not handling_host_respawn:
        return
    if handling_host_respawn or not _can_sample_player():
        return
    if not _has_live_peer():
        local_fake_death_pending = false
        _stabilize_local_player_after_fake_death()
        return

    handling_host_respawn = true
    host_respawn_sequence += 1
    var respawn_sequence: int = host_respawn_sequence
    if _has_live_peer():
        sync_host_respawn_state.rpc(true)
    host_respawning = true

    Steamworks.increment_statistic("death_count")
    Steamworks.set_achievement("DEATH")
    _stop_local_player_actions()
    if panel_visible:
        toggle_panel(false)

    Ref.player.disabled = true
    _stabilize_local_player_after_fake_death(false)
    var remote_anchor: Vector3 = _get_remote_respawn_anchor(false, Ref.player.global_position)
    var has_remote_anchor: bool = _has_remote_respawn_anchor(false)
    _set_death_overlay_visible(true, "Respawning near partner..." if has_remote_anchor else "Respawning at spawn point...")
    _broadcast_local_state_now()

    var respawn_position: Vector3 = await _resolve_respawn_position()
    if respawn_sequence != host_respawn_sequence or not handling_host_respawn or not host_respawning or local_quit_in_progress or not _can_sample_player():
        if respawn_sequence == host_respawn_sequence:
            local_fake_death_pending = false
            handling_host_respawn = false
            host_respawning = false
            _set_death_overlay_visible(false)
        return
    if _has_remote_respawn_anchor(false):
        remote_anchor = _get_remote_respawn_anchor(false, remote_anchor)
        respawn_position = _find_safe_respawn_position_near(remote_anchor, respawn_position)
    local_fake_death_respawn_target = respawn_position
    local_fake_death_respawn_target_valid = true
    await get_tree().create_timer(1.35, false).timeout

    if respawn_sequence != host_respawn_sequence or not handling_host_respawn or not host_respawning or local_quit_in_progress or not _can_sample_player():
        if respawn_sequence == host_respawn_sequence:
            local_fake_death_pending = false
            handling_host_respawn = false
            host_respawning = false
            _set_death_overlay_visible(false)
        return

    Ref.player.revive()
    Ref.player.dead = false
    Ref.player.disabled = false
    Ref.player.make_invincible_temporary()
    _teleport_local_player_exact(respawn_position)
    Ref.player.consume_actions()
    _set_death_overlay_visible(false)

    status_message = "Respawned"
    _update_status_text()
    local_fake_death_pending = false
    local_fake_death_save_override.clear()
    host_respawning = false
    if _has_live_peer():
        sync_host_respawn_state.rpc(false)
    _broadcast_local_state_now()
    handling_host_respawn = false


func _resync_host_world_to_clients() -> void:
    if not multiplayer.is_server() or not _has_live_peer():
        return

    for peer_id in peer_states.keys():
        var int_peer_id: int = int(peer_id)
        if int_peer_id == 1:
            continue
        _send_world_snapshot_to_peer.call_deferred(int_peer_id)


func _handle_client_player_death() -> void:
    if not local_fake_death_pending and not handling_client_respawn:
        return
    if handling_client_respawn or not _can_sample_player():
        return
    if not _has_live_peer():
        local_fake_death_pending = false
        _stabilize_local_player_after_fake_death()
        return

    handling_client_respawn = true
    _broadcast_local_state_now()
    _stop_local_player_actions()
    Ref.player.dead = false
    Ref.player.disabled = false
    Ref.player.revive()
    Ref.player.make_invincible_temporary()

    var fallback_respawn_position: Vector3 = _resolve_default_respawn_fallback_position(Ref.player.global_position + Vector3(1.5, 0.0, 0.0))
    var has_host_anchor: bool = _has_remote_respawn_anchor(true)
    var respawn_anchor: Vector3 = _get_remote_respawn_anchor(true, fallback_respawn_position)
    var respawn_position: Vector3 = _find_safe_respawn_position_near(respawn_anchor, fallback_respawn_position)
    local_fake_death_respawn_target = respawn_position
    local_fake_death_respawn_target_valid = true
    _teleport_local_player_exact(respawn_position)
    if _has_live_peer():
        _send_persistent_state_to_host()
    status_message = "You died and respawned near host" if has_host_anchor else "You died and respawned at spawn"
    _update_status_text()
    local_fake_death_pending = false
    local_fake_death_save_override.clear()
    handling_client_respawn = false
    _broadcast_local_state_now()


func _prepare_client_world_sync() -> void:
    if multiplayer.is_server() or not is_instance_valid(Ref.main) or not Ref.main.loaded:
        return
    if client_world_sync_ready:
        return

    if is_instance_valid(Ref.entity_spawner):
        if _is_local_world_authority():
            Ref.entity_spawner.start_spawning()
        else:
            Ref.entity_spawner.stop_spawning()

    if _is_local_world_authority():
        synced_entities.clear()
        synced_dropped_items.clear()
        client_world_sync_ready = true
        return

    if ENABLE_ENTITY_SYNC:
        _adopt_existing_client_world_entities_and_drops()
    else:
        _clear_client_world_entities_and_drops()
    client_world_sync_ready = true


func _clear_client_world_entities_and_drops() -> void:
    synced_entities.clear()
    synced_dropped_items.clear()
    client_collected_drop_uuids.clear()
    entity_interp_map.clear()
    host_entity_last_sent.clear()
    client_server_time_initialized = false
    client_last_world_state_sequence = -1

    for child in _get_live_tracked_entities():
        child.call_deferred("queue_free")
    for child in _get_live_tracked_drops():
        child.call_deferred("queue_free")
    tracked_root_entities.clear()
    tracked_root_drops.clear()

    for child in get_tree().get_root().get_children():
        if child is Player:
            continue
        if child is Entity or child is DroppedItem:
            child.call_deferred("queue_free")


func _adopt_existing_client_world_entities_and_drops() -> void:
    synced_entities.clear()
    synced_dropped_items.clear()
    client_last_world_state_sequence = -1

    for child in _get_live_tracked_entities():
        if child is Player:
            continue
        if child is Entity:
            var entity_uuid: String = _get_sync_uuid(child)
            if entity_uuid != "":
                synced_entities[entity_uuid] = child
                _configure_client_synced_entity(child, entity_uuid)
            else:
                _prepare_existing_client_entity(child)
    for child in _get_live_tracked_drops():
        if child is Player:
            continue
        if child is DroppedItem:
            var drop_uuid: String = _get_sync_uuid(child)
            if drop_uuid == "":
                continue
            synced_dropped_items[drop_uuid] = child
            _configure_client_synced_drop(child, drop_uuid)


func _prepare_existing_client_entity(entity) -> void:
    if entity == null or not is_instance_valid(entity):
        return
    entity.set_meta("coop_candidate_existing", true)
    entity.set_meta("coop_client_entity_created_msec", Time.get_ticks_msec())
    _disable_client_entity_runtime(entity)
    if entity is Entity:
        entity.disabled = false
        entity.disabled_by_visibility = false
        entity.invincible = true
        entity.invincible_temporary = true
        var visible_enabler: VisibleOnScreenEnabler3D = entity.get_node_or_null("%VisibleOnScreenEnabler3D") as VisibleOnScreenEnabler3D
        if visible_enabler != null:
            visible_enabler.enable_node_path = ""


func _capture_host_drop_snapshots(focus_position: Vector3) -> Array:
    var snapshots: Array = []
    if not _can_share_loaded_world():
        return snapshots

    for child in _get_live_tracked_drops():
        if not (child is DroppedItem):
            continue

        var dropped_item := child as DroppedItem
        if not is_instance_valid(dropped_item) or dropped_item.item == null:
            continue
        if dropped_item.global_position.distance_squared_to(focus_position) > DROP_SYNC_RADIUS * DROP_SYNC_RADIUS:
            continue

        var uuid: String = _get_sync_uuid(dropped_item)
        if uuid == "":
            uuid = _assign_sync_uuid(dropped_item)
        if uuid == "":
            continue

        snapshots.append([
            uuid,
            dropped_item.global_position,
            dropped_item.velocity,
            _serialize_item_state(dropped_item.item),
            bool(dropped_item.can_collect),
        ])

    return snapshots


func _capture_host_entity_snapshots(focus_position: Vector3) -> Array:
    var snapshots: Array = []
    if not ENABLE_ENTITY_SYNC or not _can_share_loaded_world():
        return snapshots

    host_server_time = float(Time.get_ticks_msec()) / 1000.0
    for child in _get_live_tracked_entities():
        if not _is_syncable_entity_node(child):
            continue

        var entity = child as Entity
        if not is_instance_valid(entity) or not entity.is_inside_tree():
            continue
        if entity.global_position.distance_squared_to(focus_position) > ENTITY_SYNC_RADIUS * ENTITY_SYNC_RADIUS:
            continue

        var scene_path: String = _get_sync_scene_path(entity)
        if scene_path == "":
            continue

        var uuid: String = _get_sync_uuid(entity)
        if uuid == "":
            uuid = _assign_sync_uuid(entity)
        if uuid == "":
            continue

        var held_item_index: int = int(entity.held_item_index) if _object_has_property(entity, "held_item_index") else 0
        var held_item_id: int = -1
        if _object_has_property(entity, "held_item_inventory"):
            var inventory = entity.get("held_item_inventory")
            if inventory != null and _object_has_property(inventory, "items") and held_item_index >= 0 and held_item_index < inventory.items.size():
                var held_item_state = inventory.items[held_item_index]
                held_item_id = int(held_item_state.id) if held_item_state != null else -1

        var special_state: Dictionary = {}
        var last_visual_state_sent: float = float(host_entity_last_sent.get(uuid, -1000.0))
        if (host_server_time - last_visual_state_sent) >= ENTITY_VISUAL_STATE_INTERVAL:
            var horizontal_speed: float = Vector3(entity.velocity.x, 0.0, entity.velocity.z).length()
            var base_speed: float = _resolve_object_float_property(entity, ["speed"], 1.0)
            var speed_modifier: float = _resolve_object_float_property(entity, ["speed_modifier"], 1.0)
            var walk_value: float = clampf(horizontal_speed / maxf(base_speed * speed_modifier, 0.001), 0.0, 1.0)
            special_state = {
                "under_water": bool(entity.under_water),
                "walk_val": walk_value,
                "compact_anim": _capture_compact_animation_state(entity),
                "head_look": _capture_entity_model_head_look_state(entity),
                "procedural_visual": _capture_entity_procedural_visual_state(entity),
            }
            host_entity_last_sent[uuid] = host_server_time
            _maybe_broadcast_host_entity_projectile_visual(entity, special_state)

        var movement_velocity: Vector3 = entity.movement_velocity if entity is Entity else _get_entity_total_velocity(entity)
        var gravity_velocity: Vector3 = entity.gravity_velocity if entity is Entity else Vector3.ZERO
        var knockback_velocity: Vector3 = entity.knockback_velocity if entity is Entity else Vector3.ZERO
        var rope_velocity: Vector3 = entity.rope_velocity if entity is Entity else Vector3.ZERO

        snapshots.append([
            uuid,
            scene_path,
            entity.global_position,
            _get_entity_visual_yaw(entity),
            movement_velocity,
            gravity_velocity,
            knockback_velocity,
            rope_velocity,
            bool(entity.dead),
            bool(entity.disabled),
            host_server_time,
            held_item_id,
            held_item_index,
            special_state,
        ])

    return snapshots


var _property_cache: Dictionary = {}

func _object_has_property(target: Object, property_name: String) -> bool:
    if target == null:
        return false
    var class_name_key: String = target.get_class()
    if target.get_script() != null:
        class_name_key = str(target.get_script().resource_path)
    var cache_key: String = class_name_key + ":" + property_name
    if _property_cache.has(cache_key):
        return bool(_property_cache[cache_key])
    var found: bool = property_name in target
    _property_cache[cache_key] = found
    return found


func _apply_entity_special_state(entity, special_state: Dictionary) -> void:
    if entity == null or not is_instance_valid(entity) or special_state.is_empty():
        return

    if entity is Entity and special_state.has("under_water"):
        entity.under_water = bool(special_state.get("under_water", false))

    var head_look_state = special_state.get("head_look", {})
    if head_look_state is Dictionary:
        entity.set_meta("coop_head_look_state", head_look_state.duplicate(true))
        _apply_entity_model_head_look_state(entity, head_look_state)

    var procedural_visual_state = special_state.get("procedural_visual", {})
    if procedural_visual_state is Dictionary:
        _apply_entity_procedural_visual_state(entity, procedural_visual_state)

    var compact_anim: Dictionary = special_state.get("compact_anim", {}) if special_state.has("compact_anim") and special_state["compact_anim"] is Dictionary else {}
    entity.set_meta("coop_compact_anim_state", compact_anim.duplicate(true))
    var walk_val: float = float(special_state.get("walk_val", -1.0))
    if walk_val >= 0.0:
        _apply_interp_animation(entity, walk_val, compact_anim)
    else:
        _apply_compact_animation_state(entity, compact_anim)


func _apply_client_world_state(sequence: int, drop_snapshots: Array, entity_snapshots: Array = []) -> void:
    if sequence <= client_last_world_state_sequence:
        return
    client_last_world_state_sequence = sequence
    _prepare_client_world_sync()
    if ENABLE_ENTITY_SYNC:
        _apply_client_entity_snapshots(entity_snapshots, sequence)
    else:
        _purge_client_entities()
    _apply_client_drop_snapshots(drop_snapshots)


func _purge_client_entities() -> void:
    for uuid in synced_entities.keys().duplicate():
        var synced_entity = synced_entities[uuid]
        if is_instance_valid(synced_entity):
            synced_entity.call_deferred("queue_free")
    synced_entities.clear()
    entity_interp_map.clear()
    for child in _get_live_tracked_entities():
        if _is_syncable_entity_node(child):
            child.call_deferred("queue_free")


func _apply_client_entity_snapshots(entity_snapshots: Array, sequence: int = 0) -> void:
    var visible_uuids: Dictionary = {}

    for entry in entity_snapshots:
        if not (entry is Array) or entry.size() < 10:
            continue

        var uuid: String = str(entry[0])
        var scene_path: String = str(entry[1])
        var entity_position: Vector3 = entry[2]
        var entity_yaw: float = float(entry[3])
        var entity_velocity: Vector3 = Vector3.ZERO
        var movement_velocity: Vector3 = entity_velocity
        var gravity_velocity: Vector3 = Vector3.ZERO
        var knockback_velocity: Vector3 = Vector3.ZERO
        var rope_velocity: Vector3 = Vector3.ZERO
        var dead: bool = false
        var disabled: bool = false
        var server_time: float = 0.0
        var held_item_id: int = -1
        var held_item_index: int = 0
        var special_state: Dictionary = {}
        if entry.size() >= 15:
            entity_velocity = entry[4]
            movement_velocity = entry[5]
            gravity_velocity = entry[6]
            knockback_velocity = entry[7]
            rope_velocity = entry[8]
            dead = bool(entry[9])
            disabled = bool(entry[10])
            server_time = float(entry[11])
            held_item_id = int(entry[12])
            held_item_index = int(entry[13])
            special_state = entry[14] if entry[14] is Dictionary else {}
        elif entry.size() >= 14:
            movement_velocity = entry[4]
            gravity_velocity = entry[5]
            knockback_velocity = entry[6]
            rope_velocity = entry[7]
            entity_velocity = movement_velocity + gravity_velocity + knockback_velocity + rope_velocity
            dead = bool(entry[8])
            disabled = bool(entry[9])
            server_time = float(entry[10])
            held_item_id = int(entry[11])
            held_item_index = int(entry[12])
            special_state = entry[13] if entry[13] is Dictionary else {}
        else:
            entity_velocity = entry[4]
            dead = bool(entry[5])
            disabled = bool(entry[6])
            server_time = float(entry[7])
            held_item_id = int(entry[8])
            held_item_index = int(entry[9])
            special_state = entry[10] if entry.size() >= 11 and entry[10] is Dictionary else {}
        if uuid == "" or scene_path == "":
            continue

        visible_uuids[uuid] = true
        if server_time > 0.0:
            client_server_time = maxf(client_server_time, server_time)
            client_server_time_initialized = true

        var entity = synced_entities.get(uuid, null)
        if not is_instance_valid(entity):
            entity = _find_existing_entity_by_uuid(uuid)
        if not is_instance_valid(entity):
            entity = _find_existing_entity_by_scene_and_position(scene_path, entity_position)
        if not is_instance_valid(entity):
            entity = _spawn_client_synced_entity(uuid, scene_path)
        if not is_instance_valid(entity):
            continue

        synced_entities[uuid] = entity
        _configure_client_synced_entity(entity, uuid)
        entity.set_meta("coop_last_snapshot_msec", Time.get_ticks_msec())
        entity.visible = not dead

        if entity is Entity:
            entity.disabled = disabled
            entity.disabled_by_visibility = false
            entity.invincible = true
            entity.invincible_temporary = true

        _apply_entity_held_item_state(entity, held_item_id, held_item_index)
        _apply_entity_special_state(entity, special_state)
        _apply_client_entity_snapshot(entity, entity_position, entity_yaw, entity_velocity, server_time, movement_velocity, gravity_velocity, knockback_velocity, rope_velocity, sequence)

    _remove_unlisted_client_entities(visible_uuids)


func _apply_client_drop_snapshots(drop_snapshots: Array) -> void:
    var visible_uuids: Dictionary = {}

    for entry in drop_snapshots:
        if not (entry is Array) or entry.size() < 4:
            continue

        var uuid: String = str(entry[0])
        var drop_position: Vector3 = entry[1]
        var drop_velocity: Vector3 = entry[2]
        var item_data: PackedInt32Array = entry[3]
        var can_collect: bool = bool(entry[4]) if entry.size() >= 5 else true
        if uuid == "" or item_data.is_empty():
            continue
        if client_collected_drop_uuids.has(uuid):
            visible_uuids[uuid] = true
            continue

        var dropped_item = synced_dropped_items.get(uuid, null)
        if not is_instance_valid(dropped_item):
            dropped_item = _find_existing_drop_by_uuid(uuid)

        var item_state = _deserialize_item_state(item_data)
        if item_state == null:
            continue

        if is_instance_valid(dropped_item) and dropped_item.item != null and int(dropped_item.item.id) != int(item_state.id):
            dropped_item.call_deferred("queue_free")
            dropped_item = null

        if not is_instance_valid(dropped_item):
            dropped_item = _find_matching_predicted_drop(item_state, drop_position)
            if is_instance_valid(dropped_item):
                _configure_client_synced_drop(dropped_item, uuid)

        if not is_instance_valid(dropped_item):
            dropped_item = _spawn_client_synced_drop(uuid, item_state)
        if not is_instance_valid(dropped_item):
            continue

        synced_dropped_items[uuid] = dropped_item
        visible_uuids[uuid] = true
        _apply_client_drop_snapshot(dropped_item, item_state, drop_position, drop_velocity, can_collect)

    for uuid in synced_dropped_items.keys().duplicate():
        if visible_uuids.has(uuid):
            continue
        if is_instance_valid(synced_dropped_items[uuid]):
            synced_dropped_items[uuid].call_deferred("queue_free")
        synced_dropped_items.erase(uuid)

    _remove_unlisted_client_drops(visible_uuids)


func _spawn_client_synced_entity(uuid: String, scene_path: String):
    var scene = load(scene_path)
    if not (scene is PackedScene):
        return null

    var entity = scene.instantiate()
    if entity == null or not (entity is Entity):
        if entity != null:
            entity.queue_free()
        return null

    entity.set_meta("coop_source_scene_path", scene_path)
    get_tree().get_root().add_child(entity)
    _configure_client_synced_entity(entity, uuid)
    return entity


func _spawn_client_synced_drop(uuid: String, item_state):
    var scene = load(DROPPED_ITEM_SCENE_PATH)
    if not (scene is PackedScene):
        return null

    var dropped_item = scene.instantiate()
    if dropped_item == null:
        return null

    if dropped_item is DroppedItem:
        dropped_item.disabled = true

    get_tree().get_root().add_child(dropped_item)
    if Ref.preserve_node_manager != null:
        Ref.preserve_node_manager.node_to_uuid_map[dropped_item] = uuid
    dropped_item.initialize(item_state, true)
    _configure_client_synced_drop(dropped_item, uuid)
    return dropped_item


func _find_existing_entity_by_uuid(uuid: String):
    if uuid == "":
        return null
    for child in _get_live_tracked_entities():
        if _get_sync_uuid(child) == uuid:
            return child
    return null


func _find_existing_entity_by_scene_and_position(scene_path: String, world_position: Vector3, max_distance: float = 8.0):
    var best_match = null
    var best_distance_squared: float = max_distance * max_distance
    for child in _get_live_tracked_entities():
        if not _is_syncable_entity_node(child):
            continue
        var existing_uuid: String = _get_sync_uuid(child)
        if existing_uuid != "" and synced_entities.get(existing_uuid, null) == child:
            continue
        if _get_sync_scene_path(child) != scene_path:
            continue
        var distance_squared: float = child.global_position.distance_squared_to(world_position)
        if distance_squared > best_distance_squared:
            continue
        best_distance_squared = distance_squared
        best_match = child
    return best_match


func _find_existing_drop_by_uuid(uuid: String):
    for child in _get_live_tracked_drops():
        if child is DroppedItem and _get_sync_uuid(child) == uuid:
            return child
    return null


func _assign_sync_uuid(node: Node) -> String:
    var existing_uuid: String = _get_sync_uuid(node)
    if existing_uuid != "":
        node.set_meta("coop_uuid", existing_uuid)
        return existing_uuid

    var new_uuid: String = UUID.v4()
    node.set_meta("coop_uuid", new_uuid)
    if Ref.preserve_node_manager != null:
        Ref.preserve_node_manager.node_to_uuid_map[node] = new_uuid
    return new_uuid


func _remove_unlisted_client_entities(visible_uuids: Dictionary) -> void:
    for uuid in synced_entities.keys().duplicate():
        if visible_uuids.has(uuid):
            continue
        var entity = synced_entities[uuid]
        if not is_instance_valid(entity):
            synced_entities.erase(uuid)
            entity_interp_map.erase(uuid)
            continue
        if not _should_prune_client_synced_entity(entity):
            continue
        entity.call_deferred("queue_free")
        synced_entities.erase(uuid)
        entity_interp_map.erase(uuid)

    for child in _get_live_tracked_entities():
        if not _is_syncable_entity_node(child):
            continue
        if not bool(child.get_meta("coop_candidate_existing", false)):
            continue
        if not _should_prune_client_synced_entity(child):
            continue
        child.call_deferred("queue_free")


func _remove_unlisted_client_drops(visible_uuids: Dictionary) -> void:
    for child in _get_live_tracked_drops():
        if not (child is DroppedItem):
            continue
        if bool(child.get_meta("coop_predicted_drop", false)):
            continue
        var uuid: String = _get_sync_uuid(child)
        if uuid == "" or not visible_uuids.has(uuid):
            if not bool(child.get_meta("coop_merge_cleanup_pending", false)):
                _animate_client_drop_merge_removal.call_deferred(child)


func _configure_client_synced_entity(entity, uuid: String) -> void:
    if entity == null or not is_instance_valid(entity):
        return
    entity.set_meta("coop_uuid", uuid)
    entity.set_meta("coop_synced_entity", true)
    entity.set_meta("coop_candidate_existing", false)
    entity.set_meta("coop_client_entity_created_msec", int(entity.get_meta("coop_client_entity_created_msec", Time.get_ticks_msec())))
    if Ref.preserve_node_manager != null:
        Ref.preserve_node_manager.node_to_uuid_map[entity] = uuid
    if not tracked_root_entities.has(entity):
        tracked_root_entities.append(entity)
    _disable_client_entity_runtime(entity)
    if entity is Entity:
        entity.disabled_by_visibility = false
        entity.invincible = true
        entity.invincible_temporary = true
        var visible_enabler: VisibleOnScreenEnabler3D = entity.get_node_or_null("%VisibleOnScreenEnabler3D") as VisibleOnScreenEnabler3D
        if visible_enabler != null:
            visible_enabler.enable_node_path = ""
            visible_enabler.process_mode = Node.PROCESS_MODE_DISABLED


func _configure_client_synced_drop(dropped_item, uuid: String) -> void:
    if dropped_item == null:
        return
    var was_predicted: bool = bool(dropped_item.get_meta("coop_predicted_drop", false))
    dropped_item.set_meta("coop_uuid", uuid)
    dropped_item.set_meta("coop_synced_drop", true)
    dropped_item.remove_meta("coop_predicted_drop")
    dropped_item.remove_meta("coop_predicted_created_ms")
    dropped_item.remove_meta("coop_predicted_item_signature")
    dropped_item.set_meta("coop_pickup_pending_request", false)
    dropped_item.set_meta("coop_merge_cleanup_pending", false)
    if was_predicted:
        dropped_item.set_meta("coop_predicted_sync_grace_until_ms", Time.get_ticks_msec() + CLIENT_PREDICTED_DROP_SYNC_GRACE_MS)
    if dropped_item is DroppedItem:
        dropped_item.disabled = false
        dropped_item.can_merge = false
        dropped_item.can_collect = false
        dropped_item.is_collect_delayed = false
        dropped_item.is_merge_delayed = false
        dropped_item.toggle_physics(true)
    dropped_item.set_physics_process(true)


func _disable_client_entity_runtime(root: Node, preserve_interact_branch: bool = false) -> void:
    if root == null or not is_instance_valid(root):
        return

    if root.has_method("set_process"):
        root.set_process(false)
    if root.has_method("set_physics_process"):
        root.set_physics_process(false)
    if root.has_method("set_process_input"):
        root.set_process_input(false)
    if root.has_method("set_process_unhandled_input"):
        root.set_process_unhandled_input(false)

    _disable_client_entity_runtime_branch(root, root, preserve_interact_branch)


func _disable_client_entity_runtime_branch(root: Node, node: Node, preserve_interact_branch: bool) -> void:
    if node == null or not is_instance_valid(node):
        return

    if node is Timer:
        (node as Timer).stop()

    if node is Area3D:
        var area := node as Area3D
        if not (preserve_interact_branch and _should_keep_client_entity_area_active(area)):
            area.monitoring = false
            area.monitorable = false
            area.collision_layer = 0
            area.collision_mask = 0
    elif node is PhysicsBody3D:
        var body := node as PhysicsBody3D
        body.collision_layer = 0
        body.collision_mask = 0
        if node != root:
            body.set_physics_process(false)

    if node is CollisionShape3D or node is CollisionPolygon3D:
        if _object_has_property(node, "disabled"):
            node.set_deferred("disabled", true)

    var keep_animation_runtime: bool = node is AnimationTree or node is AnimationPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer or _is_entity_model_node(node)
    if node != root and not keep_animation_runtime:
        if node.has_method("set_process"):
            node.set_process(false)
        if node.has_method("set_physics_process"):
            node.set_physics_process(false)
        if node.has_method("set_process_input"):
            node.set_process_input(false)
        if node.has_method("set_process_unhandled_input"):
            node.set_process_unhandled_input(false)

    for child in node.get_children():
        _disable_client_entity_runtime_branch(root, child, preserve_interact_branch)


func _apply_client_entity_snapshot(entity, entity_position: Vector3, entity_yaw: float, entity_velocity: Vector3, server_time: float = 0.0, movement_velocity: Vector3 = Vector3.ZERO, gravity_velocity: Vector3 = Vector3.ZERO, knockback_velocity: Vector3 = Vector3.ZERO, rope_velocity: Vector3 = Vector3.ZERO, seq: int = 0) -> void:
    if entity == null or not is_instance_valid(entity):
        return

    var uuid: String = _get_sync_uuid(entity)
    var current_yaw: float = _get_entity_visual_yaw(entity)
    var local_receive_time: float = float(Time.get_ticks_msec()) / 1000.0
    var duration: float = maxf(WORLD_STATE_INTERVAL, 0.001)
    if uuid != "" and entity_interp_map.has(uuid):
        var existing_interp: Dictionary = entity_interp_map[uuid]
        var previous_receive_time: float = float(existing_interp.get("received_local_time", local_receive_time - duration))
        duration = clampf(local_receive_time - previous_receive_time, WORLD_STATE_INTERVAL * 0.75, maxf(ENTITY_DR_HEARTBEAT_SEC, WORLD_STATE_INTERVAL * 2.0))
    var yaw_delta: float = wrapf(entity_yaw - current_yaw + PI, 0.0, TAU) - PI
    if not bool(entity.get_meta("coop_entity_snapshot_initialized", false)) or entity.global_position.distance_squared_to(entity_position) > 36.0:
        entity.global_position = entity_position
        _set_entity_visual_yaw(entity, entity_yaw)
        if entity.has_method("override_position"):
            entity.override_position()
        entity.set_meta("coop_entity_snapshot_initialized", true)
        if uuid != "":
            entity_interp_map[uuid] = {
                "entity": entity,
                "from_position": entity_position,
                "to_position": entity_position,
                "from_yaw": entity_yaw,
                "to_yaw": entity_yaw,
                "velocity": entity_velocity,
                "elapsed": 0.0,
                "duration": duration,
                "server_time": server_time,
                "seq": seq,
                "yaw_velocity": 0.0,
                "received_local_time": local_receive_time,
            }
    elif uuid != "":
        entity_interp_map[uuid] = {
            "entity": entity,
            "from_position": entity.global_position,
            "to_position": entity_position,
            "from_yaw": current_yaw,
            "to_yaw": entity_yaw,
            "velocity": entity_velocity,
            "elapsed": 0.0,
            "duration": duration,
            "server_time": server_time,
            "seq": seq,
            "yaw_velocity": yaw_delta / duration,
            "received_local_time": local_receive_time,
        }

    if entity is Entity:
        entity.velocity = entity_velocity
        entity.movement_velocity = movement_velocity
        entity.gravity_velocity = gravity_velocity
        entity.knockback_velocity = knockback_velocity
        entity.rope_velocity = rope_velocity
    elif "velocity" in entity:
        entity.velocity = entity_velocity


func _tick_entity_interpolation(delta: float) -> void:
    if entity_interp_map.is_empty():
        return

    for uuid in entity_interp_map.keys().duplicate():
        var interp: Dictionary = entity_interp_map[uuid]
        var entity = interp.get("entity", null)
        if entity == null or not is_instance_valid(entity):
            entity_interp_map.erase(uuid)
            synced_entities.erase(uuid)
            continue

        var duration: float = maxf(float(interp.get("duration", WORLD_STATE_INTERVAL)), 0.001)
        var elapsed: float = float(interp.get("elapsed", 0.0)) + delta
        var weight: float = clampf(elapsed / duration, 0.0, 1.0)
        var from_position: Vector3 = interp.get("from_position", entity.global_position)
        var to_position: Vector3 = interp.get("to_position", entity.global_position)
        var predicted_extra: float = minf(maxf(elapsed - duration, 0.0), ENTITY_DR_HEARTBEAT_SEC)
        entity.global_position = from_position.lerp(to_position, weight) + interp.get("velocity", Vector3.ZERO) * predicted_extra
        var entity_yaw: float = lerp_angle(float(interp.get("from_yaw", _get_entity_visual_yaw(entity))), float(interp.get("to_yaw", _get_entity_visual_yaw(entity))), weight) + float(interp.get("yaw_velocity", 0.0)) * predicted_extra
        _set_entity_visual_yaw(entity, entity_yaw)
        if entity.has_method("override_position"):
            entity.override_position()
        interp["elapsed"] = elapsed
        entity_interp_map[uuid] = interp


func _tick_client_synced_entity_visuals(delta: float) -> void:
    if synced_entities.is_empty():
        return

    for uuid in synced_entities.keys().duplicate():
        var entity = synced_entities[uuid]
        if entity == null or not is_instance_valid(entity):
            continue
        var entity_velocity: Vector3 = _get_entity_total_velocity(entity)
        if entity_interp_map.has(uuid):
            var interp = entity_interp_map[uuid]
            if interp is Dictionary:
                entity_velocity = interp.get("velocity", entity_velocity)
        _update_client_entity_visuals(entity, entity_velocity, delta)


func _apply_interp_animation(entity, walk_val: float, compact_anim: Dictionary) -> void:
    var animation_tree: AnimationTree = _find_first_animation_tree(entity)
    _apply_compact_animation_state(entity, compact_anim)
    if animation_tree != null:
        if _animation_tree_has_parameter(animation_tree, "parameters/walk/blend_amount"):
            animation_tree.set("parameters/walk/blend_amount", walk_val)
        if _animation_tree_has_parameter(animation_tree, "parameters/run/blend_amount"):
            animation_tree.set("parameters/run/blend_amount", walk_val)


func _update_client_entity_visuals(entity, entity_velocity: Vector3, _delta: float) -> void:
    if entity == null or not is_instance_valid(entity):
        return
    if entity.has_method("override_position"):
        entity.override_position()
    _update_client_procedural_entity_visuals(entity, _delta)
    var base_speed: float = _resolve_object_float_property(entity, ["speed"], 1.0)
    var speed_modifier: float = _resolve_object_float_property(entity, ["speed_modifier"], 1.0)
    var walk_val: float = clampf(Vector3(entity_velocity.x, 0.0, entity_velocity.z).length() / maxf(base_speed * speed_modifier, 0.001), 0.0, 1.0)
    var compact_anim: Dictionary = entity.get_meta("coop_compact_anim_state", {}) if entity.has_meta("coop_compact_anim_state") else {}
    _apply_interp_animation(entity, walk_val, compact_anim if compact_anim is Dictionary else {})
    _advance_client_animation_tree(entity, _delta)


func _capture_compact_animation_state(root: Node) -> Dictionary:
    var animation_tree: AnimationTree = _find_first_animation_tree(root)
    if animation_tree == null:
        return {}

    var state: Dictionary = {}
    for property_info in animation_tree.get_property_list():
        var property_name: String = str(property_info.get("name", ""))
        if not property_name.begins_with("parameters/"):
            continue
        if property_name.ends_with("/internal_active"):
            continue
        var leaf_name: String = property_name.get_slice("/", property_name.get_slice_count("/") - 1)
        if leaf_name not in ["blend_amount", "blend_position", "request", "scale", "active"]:
            continue

        var value: Variant = animation_tree.get(property_name)
        match typeof(value):
            TYPE_BOOL, TYPE_INT:
                state[property_name] = value
            TYPE_FLOAT:
                state[property_name] = _quantize_float(float(value), 0.01)
            TYPE_VECTOR2:
                var vec2_value: Vector2 = value
                state[property_name] = Vector2(
                    _quantize_float(vec2_value.x, 0.01),
                    _quantize_float(vec2_value.y, 0.01)
                )
            TYPE_VECTOR3:
                state[property_name] = _quantize_vector3(value, 0.01)
    return state


func _resolve_host_visual_projectile_start(entity) -> Vector3:
    if entity == null or not is_instance_valid(entity):
        return Vector3.ZERO

    var hand_node: Node3D = entity.get_node_or_null("%Hand") as Node3D
    if hand_node == null and _object_has_property(entity, "hand"):
        var hand_value: Variant = entity.get("hand")
        if hand_value is Node3D and is_instance_valid(hand_value):
            hand_node = hand_value
    if hand_node != null:
        return hand_node.global_position

    var head_node: Node3D = entity.get_node_or_null("%Head") as Node3D
    if head_node == null and _object_has_property(entity, "head"):
        var head_value: Variant = entity.get("head")
        if head_value is Node3D and is_instance_valid(head_value):
            head_node = head_value
    if head_node != null:
        return head_node.global_position

    return entity.global_position + Vector3(0.0, 1.2, 0.0)


func _resolve_host_visual_projectile_direction(entity) -> Vector3:
    if entity == null or not is_instance_valid(entity):
        return Vector3.FORWARD

    var direction: Vector3 = Vector3.ZERO
    if entity.has_method("get_look_direction"):
        direction = entity.get_look_direction()
    else:
        direction = -entity.global_basis.z
    if direction.is_zero_approx():
        direction = -entity.global_basis.z
    return direction.normalized()


func _resolve_object_float_property(target: Object, property_names: Array, default_value: float) -> float:
    if target == null:
        return default_value
    for property_name_value in property_names:
        var property_name: String = str(property_name_value)
        if _object_has_property(target, property_name):
            return float(target.get(property_name))
    return default_value


func _resolve_host_visual_ball_linear_velocity(entity, held_item = null) -> Vector3:
    var direction: Vector3 = _resolve_host_visual_projectile_direction(entity)
    var speed: float = _resolve_object_float_property(held_item, ["throw_speed", "projectile_speed", "speed"], 12.0)
    if speed <= 0.0:
        speed = 12.0
    return direction * speed + _get_entity_total_velocity(entity)


func _get_compact_anim_request(compact_anim: Dictionary, node_name: String) -> int:
    if compact_anim.is_empty() or node_name == "":
        return 0
    var request_path: String = "parameters/%s/request" % node_name
    return int(compact_anim.get(request_path, 0))


func _maybe_broadcast_host_entity_projectile_visual(entity, special_state: Dictionary) -> void:
    if not multiplayer.is_server() or not _has_live_peer() or entity == null or special_state.is_empty():
        return

    var compact_anim: Dictionary = special_state.get("compact_anim", {}) if special_state.has("compact_anim") and special_state["compact_anim"] is Dictionary else {}
    var shoot_request: int = _get_compact_anim_request(compact_anim, "shoot")
    var previous_request: int = int(entity.get_meta("coop_host_visual_shoot_request", 0))
    entity.set_meta("coop_host_visual_shoot_request", shoot_request)
    if shoot_request == 0 or previous_request == shoot_request:
        return

    var held_item = entity.get("held_item") if _object_has_property(entity, "held_item") else null
    var held_item_script_path: String = _get_object_script_path(held_item)
    var start_position: Vector3 = _resolve_host_visual_projectile_start(entity)
    if held_item_script_path.contains("/held_ball_thrower/"):
        broadcast_host_visual_ball_throw(start_position, _resolve_host_visual_ball_linear_velocity(entity, held_item))
    elif held_item_script_path.contains("/held_rod_thrower/"):
        broadcast_host_visual_bolt(start_position, _resolve_host_visual_projectile_direction(entity))


func _apply_compact_animation_state(root: Node, state: Dictionary) -> void:
    if root == null or not is_instance_valid(root) or state.is_empty():
        return

    var animation_tree: AnimationTree = _find_first_animation_tree(root)
    if animation_tree == null:
        return

    var request_state: Dictionary = root.get_meta("coop_anim_request_state", {}) if root.has_meta("coop_anim_request_state") else {}
    if not (request_state is Dictionary):
        request_state = {}

    for property_name_value in state.keys():
        var property_name: String = str(property_name_value)
        if property_name == "" or not _animation_tree_has_parameter(animation_tree, property_name):
            continue

        var value: Variant = state[property_name_value]
        if property_name.ends_with("/request"):
            var previous_request: Variant = request_state.get(property_name, null)
            if previous_request == value:
                continue
            request_state[property_name] = value
        animation_tree.set(property_name, value)

    root.set_meta("coop_anim_request_state", request_state)


func _apply_entity_held_item_state(entity, held_item_id: int, held_item_index: int) -> void:
    if entity == null or not is_instance_valid(entity) or not (entity is Entity):
        return
    if held_item_index < 0 or held_item_id < 0:
        return
    if not _object_has_property(entity, "held_item_inventory"):
        return

    var inventory = entity.get("held_item_inventory")
    if inventory == null or not _object_has_property(inventory, "items") or held_item_index >= inventory.items.size():
        return

    var existing_state = inventory.items[held_item_index]
    if existing_state == null or int(existing_state.id) != held_item_id:
        var item = ItemMap.map(held_item_id)
        if item != null:
            var new_item_state := ItemState.new()
            new_item_state.initialize(item)
            inventory.set_item(held_item_index, new_item_state)

    if int(entity.held_item_index) != held_item_index:
        entity.held_item_index = held_item_index


func _find_first_animation_tree(root: Node) -> AnimationTree:
    if root == null or not is_instance_valid(root):
        return null
    if root.has_meta("coop_animation_tree_node"):
        var cached_tree = root.get_meta("coop_animation_tree_node")
        if cached_tree is AnimationTree and is_instance_valid(cached_tree):
            return cached_tree
        if str(cached_tree) == "false":
            return null
        root.remove_meta("coop_animation_tree_node")
    var found: AnimationTree = _search_first_animation_tree(root)
    root.set_meta("coop_animation_tree_node", found if found != null else false)
    return found


func _find_first_animation_player(root: Node) -> AnimationPlayer:
    if root == null or not is_instance_valid(root):
        return null
    if root.has_meta("coop_animation_player_node"):
        var cached_player = root.get_meta("coop_animation_player_node")
        if cached_player is AnimationPlayer and is_instance_valid(cached_player):
            return cached_player
        if str(cached_player) == "false":
            return null
        root.remove_meta("coop_animation_player_node")
    var found: AnimationPlayer = _search_first_animation_player(root)
    root.set_meta("coop_animation_player_node", found if found != null else false)
    return found


func _search_first_animation_tree(root: Node) -> AnimationTree:
    if root is AnimationTree:
        return root as AnimationTree
    for child in root.get_children():
        var found: AnimationTree = _search_first_animation_tree(child)
        if found != null:
            return found
    return null


func _search_first_animation_player(root: Node) -> AnimationPlayer:
    if root is AnimationPlayer:
        return root as AnimationPlayer
    for child in root.get_children():
        var found: AnimationPlayer = _search_first_animation_player(child)
        if found != null:
            return found
    return null


func _animation_tree_has_parameter(animation_tree: AnimationTree, parameter_path: String) -> bool:
    return animation_tree != null and _object_has_property(animation_tree, parameter_path)


func _apply_client_drop_snapshot(dropped_item, item_state, drop_position: Vector3, drop_velocity: Vector3, can_collect: bool = true) -> void:
    if dropped_item is DroppedItem and (dropped_item.state == DroppedItem.COLLECTED or bool(dropped_item.get_meta("coop_pickup_pending_request", false))):
        return
    dropped_item.set_meta("coop_merge_cleanup_pending", false)

    var previous_can_collect: bool = bool(dropped_item.can_collect) if dropped_item is DroppedItem else false
    var grace_until_ms: int = int(dropped_item.get_meta("coop_predicted_sync_grace_until_ms", 0))
    var keep_predicted_motion: bool = grace_until_ms > Time.get_ticks_msec()
    var distance_error: float = dropped_item.global_position.distance_to(drop_position)

    dropped_item.item = item_state
    if not bool(dropped_item.get_meta("coop_drop_snapshot_initialized", false)):
        dropped_item.global_position = drop_position
        dropped_item.set_meta("coop_drop_snapshot_initialized", true)
        distance_error = 0.0
    elif not keep_predicted_motion:
        if distance_error > CLIENT_DROP_CORRECTION_DISTANCE:
            dropped_item.global_position = drop_position
        elif distance_error > 0.01:
            dropped_item.global_position = dropped_item.global_position.lerp(drop_position, CLIENT_DROP_POSITION_BLEND)
        distance_error = dropped_item.global_position.distance_to(drop_position)

    if dropped_item is DroppedItem:
        var should_wake_sleeping_drop: bool = distance_error > 0.35 or drop_velocity.length_squared() > 0.36
        if not keep_predicted_motion:
            if dropped_item.state != DroppedItem.SLEEPING or should_wake_sleeping_drop:
                dropped_item.velocity = dropped_item.velocity.lerp(drop_velocity, CLIENT_DROP_VELOCITY_BLEND)
            else:
                dropped_item.velocity = Vector3.ZERO
        dropped_item.can_collect = can_collect
        dropped_item.disabled = false
        if dropped_item.state == DroppedItem.SLEEPING and should_wake_sleeping_drop:
            dropped_item.state = DroppedItem.IDLE
            dropped_item.toggle_physics(true)
    else:
        dropped_item.velocity = drop_velocity

    if dropped_item is DroppedItem and can_collect and (not previous_can_collect or _is_client_drop_within_pickup_radius(dropped_item)):
        _attempt_client_auto_pickup_drop.call_deferred(dropped_item)


func _get_sync_uuid(node: Node) -> String:
    if node == null:
        return ""
    if node.has_meta("coop_uuid"):
        return str(node.get_meta("coop_uuid"))
    if Ref.preserve_node_manager == null:
        return ""
    return str(Ref.preserve_node_manager.node_to_uuid_map.get(node, ""))


func _get_client_sync_clock() -> float:
    if client_server_time_initialized:
        return client_server_time
    return float(Time.get_ticks_msec()) / 1000.0


func _should_prune_client_synced_entity(entity) -> bool:
    if entity == null or not is_instance_valid(entity):
        return true
    var last_snapshot_msec: int = int(entity.get_meta("coop_last_snapshot_msec", 0))
    var created_msec: int = int(entity.get_meta("coop_client_entity_created_msec", Time.get_ticks_msec()))
    var baseline_msec: int = last_snapshot_msec if last_snapshot_msec > 0 else created_msec
    return (Time.get_ticks_msec() - baseline_msec) > int(CLIENT_ENTITY_SYNC_GRACE_SEC * 1000.0)


func _resolve_client_attack_target(target):
    return target


func _find_host_entity_by_uuid(uuid: String):
    if uuid == "":
        return null
    for child in _get_live_tracked_entities():
        if _get_sync_uuid(child) == uuid:
            return child
    return null


func _find_host_entity_by_scene_and_position(scene_path: String, world_position: Vector3, max_distance: float = 10.0):
    return _find_existing_entity_by_scene_and_position(scene_path, world_position, max_distance)


func _find_host_drop_by_uuid(uuid: String):
    for child in get_tree().get_root().get_children():
        if child is DroppedItem and _get_sync_uuid(child) == uuid:
            return child
    return null


func _find_client_synced_entity_by_uuid(uuid: String):
    if uuid == "":
        return null
    if synced_entities.has(uuid) and is_instance_valid(synced_entities[uuid]):
        return synced_entities[uuid]
    return _find_existing_entity_by_uuid(uuid)


func _predict_client_entity_knockback(_target_uuid: String, _target, _knockback_velocity: Vector3) -> void:
    return


func _confirm_client_entity_hit(_target_uuid: String, _target, _entity_position: Vector3, _entity_yaw: float, _entity_velocity: Vector3, _knockback_velocity: Vector3, _server_time: float, _seq: int) -> void:
    return


func _play_client_entity_hit_feedback(_target, _attacker, _damage_position: Vector3, _damage: int, _attacker_position_override: Variant = null) -> void:
    return


func _apply_network_place(block_position: Vector3i, block_id: int) -> void:
    if not is_instance_valid(Ref.world):
        return
    if not Ref.world.is_position_loaded(block_position):
        pending_remote_block_changes[block_position] = block_id
        return
    _apply_loaded_network_place(block_position, block_id)


func _apply_loaded_network_place(block_position: Vector3i, block_id: int) -> void:
    var current_block = Ref.world.get_block_type_at(block_position)
    if current_block != null and int(current_block.id) == block_id:
        return
    Ref.world.place_block_at(block_position, ItemMap.map(block_id), true, true)


func _apply_network_break(block_position: Vector3i) -> void:
    if not is_instance_valid(Ref.world):
        return
    if not Ref.world.is_position_loaded(block_position):
        pending_remote_block_changes[block_position] = 0
        return
    _apply_loaded_network_break(block_position)


func _apply_loaded_network_break(block_position: Vector3i) -> void:
    if not is_instance_valid(Ref.world) or not Ref.world.is_position_loaded(block_position):
        return
    var block = Ref.world.get_block_type_at(block_position)
    if block == null:
        return
    if block.id == 0 and block.internal_name != "cutscene block":
        return
    Ref.world.break_block_at(block_position, true, false)


func _apply_network_block_changes(changes: Array) -> void:
    if not is_instance_valid(Ref.world):
        return

    for entry in changes:
        if not (entry is Array) or entry.size() < 2:
            continue
        var block_position: Vector3i = entry[0]
        var block_id: int = int(entry[1])
        if not Ref.world.is_position_loaded(block_position):
            continue

        var current_block = Ref.world.get_block_type_at(block_position)
        if block_id <= 0:
            if current_block.id == 0 and current_block.internal_name != "cutscene block":
                continue
            Ref.world.break_block_at(block_position, true, false)
        else:
            if current_block.id == block_id:
                continue
            Ref.world.place_block_at(block_position, ItemMap.map(block_id), true, true)


func _apply_network_water_cells(changes: Array) -> void:
    if not is_instance_valid(Ref.world):
        return
    for entry in changes:
        if not (entry is Array) or entry.size() < 2:
            continue
        var block_position: Vector3i = entry[0]
        var water_level: int = int(entry[1])
        if not Ref.world.is_position_loaded(block_position):
            pending_remote_water_changes[block_position] = water_level
            continue
        Ref.world.place_water_at(block_position, water_level)


func _apply_network_fire_cell(block_position: Vector3i, fire_level: int) -> void:
    if not is_instance_valid(Ref.world):
        return
    if not Ref.world.is_position_loaded(block_position):
        pending_remote_fire_changes[block_position] = fire_level
        return
    Ref.world.place_fire_at(block_position, fire_level)


func _spawn_network_item(item_state, block_position: Vector3i) -> void:
    if item_state == null:
        return
    var scene = load(DROPPED_ITEM_SCENE_PATH)
    if not (scene is PackedScene):
        return

    var dropped_item = scene.instantiate()
    if dropped_item == null:
        return

    get_tree().get_root().add_child(dropped_item)
    var drop_uuid: String = _assign_sync_uuid(dropped_item)
    dropped_item.global_position = Vector3(block_position)
    dropped_item.initialize(item_state)
    if multiplayer.is_server() and _has_live_peer():
        sync_spawn_drop.rpc(drop_uuid, _serialize_item_state(item_state), dropped_item.global_position, dropped_item.velocity, bool(dropped_item.can_collect))


func _spawn_break_drops_for_block(block, block_position: Vector3i, pickaxe: bool, axe: bool, shovel: bool, meat: bool, plant: bool) -> void:
    if block == null:
        return
    if block.pickaxe_required and not pickaxe:
        return
    if block.axe_required and not axe:
        return

    var to_drop: Array[ItemState] = []

    if block.drop_item == null and block.drop_loot == null:
        if not block.can_drop:
            return

        var default_state := ItemState.new()
        default_state.initialize(block)
        default_state.count = 1
        to_drop.append(default_state)
    if block.drop_item != null:
        var explicit_state := ItemState.new()
        explicit_state.initialize(block.drop_item)
        explicit_state.count = 1
        to_drop.append(explicit_state)
    if block.drop_loot != null:
        to_drop.append_array(block.drop_loot.realize())

    for item_index in range(to_drop.size()):
        var dropped_state: ItemState = to_drop[item_index]
        if dropped_state == null:
            continue
        var dropped_item = load(DROPPED_ITEM_SCENE_PATH)
        if not (dropped_item is PackedScene):
            return
        var new_item = (dropped_item as PackedScene).instantiate()
        if new_item == null:
            continue
        if to_drop.size() > 1 and new_item is DroppedItem:
            new_item.delay_merge()
        get_tree().get_root().add_child(new_item)
        var drop_uuid: String = _assign_sync_uuid(new_item)
        new_item.global_position = Vector3(block_position)
        new_item.initialize(dropped_state)
        if multiplayer.is_server() and _has_live_peer():
            sync_spawn_drop.rpc(drop_uuid, _serialize_item_state(dropped_state), new_item.global_position, new_item.velocity, bool(new_item.can_collect))


func _schedule_client_visual_projectile_cleanup(projectile, lifetime: float = VISUAL_PROJECTILE_LIFETIME) -> void:
    if projectile == null or not is_instance_valid(projectile) or get_tree() == null:
        return
    var cleanup_timer: SceneTreeTimer = get_tree().create_timer(lifetime, false)
    cleanup_timer.timeout.connect(func() -> void:
        if is_instance_valid(projectile):
            projectile.queue_free()
    )


func _disable_client_visual_projectile_damage(root: Node) -> void:
    if root == null or not is_instance_valid(root):
        return

    root.set_meta("coop_visual_only_projectile", true)
    if _object_has_property(root, "entity_owner"):
        root.set("entity_owner", null)
    if _object_has_property(root, "damage"):
        root.set("damage", 0)

    if root is CollisionObject3D:
        root.collision_layer = 0
        root.collision_mask = 0
    if root is Area3D:
        root.monitoring = false
        root.monitorable = false
    elif root is RayCast3D:
        root.enabled = false
        root.collision_mask = 0
    elif root is CollisionShape3D:
        root.disabled = true
    elif root is CollisionPolygon3D:
        root.disabled = true

    for child in root.get_children():
        _disable_client_visual_projectile_damage(child)


func _spawn_client_visual_projectile(scene_path: String):
    var scene = load(scene_path)
    if not (scene is PackedScene):
        return null

    var projectile = scene.instantiate()
    if projectile == null:
        return null

    _disable_client_visual_projectile_damage(projectile)
    get_tree().get_root().add_child(projectile)
    _schedule_client_visual_projectile_cleanup(projectile)
    return projectile


func _spawn_client_visual_ball_throw(start_position: Vector3, linear_velocity: Vector3) -> void:
    var projectile = _spawn_client_visual_projectile(VISUAL_BALL_SCENE_PATH)
    if projectile == null:
        return

    if projectile is Node3D:
        projectile.global_position = start_position
    elif "global_position" in projectile:
        projectile.global_position = start_position

    if "linear_velocity" in projectile:
        projectile.linear_velocity = linear_velocity
    elif "velocity" in projectile:
        projectile.velocity = linear_velocity


func _spawn_client_visual_bolt(start_position: Vector3, direction: Vector3) -> void:
    var normalized_direction: Vector3 = direction.normalized()
    if normalized_direction.is_zero_approx():
        return

    var projectile = _spawn_client_visual_projectile(VISUAL_BOLT_SCENE_PATH)
    if projectile == null:
        return

    if projectile is Node3D:
        projectile.global_position = start_position
    elif "global_position" in projectile:
        projectile.global_position = start_position

    if projectile.has_method("fire"):
        projectile.fire(normalized_direction, true)
    elif "direction" in projectile:
        projectile.direction = normalized_direction
    elif "velocity" in projectile:
        projectile.velocity = normalized_direction * _resolve_object_float_property(projectile, ["speed"], 9.0)


func broadcast_host_visual_ball_throw(start_position: Vector3, linear_velocity: Vector3) -> void:
    if not multiplayer.is_server() or not _has_live_peer():
        return
    sync_host_visual_ball_throw.rpc(start_position, linear_velocity)


func broadcast_host_visual_bolt(start_position: Vector3, direction: Vector3) -> void:
    if not multiplayer.is_server() or not _has_live_peer():
        return
    var normalized_direction: Vector3 = direction.normalized()
    if normalized_direction.is_zero_approx():
        return
    sync_host_visual_bolt.rpc(start_position, normalized_direction)


@rpc("authority", "call_remote", "unreliable")
func sync_host_visual_ball_throw(start_position: Vector3, linear_velocity: Vector3) -> void:
    if multiplayer.is_server() or receiving_host_world or _is_local_world_authority():
        return
    _mark_host_contact()
    _spawn_client_visual_ball_throw(start_position, linear_velocity)


@rpc("authority", "call_remote", "unreliable")
func sync_host_visual_bolt(start_position: Vector3, direction: Vector3) -> void:
    if multiplayer.is_server() or receiving_host_world or _is_local_world_authority():
        return
    _mark_host_contact()
    _spawn_client_visual_bolt(start_position, direction)


func _apply_client_break_feedback(break_behavior, block_position: Vector3i) -> void:
    if break_behavior.entity == null or break_behavior.entity.disabled or not break_behavior.enabled:
        return

    var block = ItemMap.map(Ref.world.get_block_type_at(block_position).id)
    var held_item = break_behavior.entity.held_item_inventory.items[break_behavior.entity.held_item_index]
    if break_behavior.decrease_held_item_durability and not (held_item != null and ItemMap.map(held_item.id).internal_name == "super drill"):
        if block.pickaxe_affinity and break_behavior.pickaxe or block.axe_affinity and break_behavior.axe or block.shovel_affinity and break_behavior.shovel or block.meat_affinity and break_behavior.meat or block.plant_affinity and break_behavior.plant:
            break_behavior.entity.decrease_held_item_durability(1)

    Steamworks.increment_statistic("blocks_broken")


@rpc("any_peer", "call_remote", "unreliable")
func submit_client_state(sequence: int, active: bool, downed: bool, dimension: int, dimension_instance_key: String, pocket_owner_key: String, position: Vector3, yaw: float, pitch: float, crouching: bool, grounded: bool, move_speed: float, under_water: bool, held_item_id: int, action_state: int, player_name: String, player_key: String, avatar_id: String, skin_color: Color, breaking: bool, break_position: Vector3i, break_block_id: int, break_progress: float) -> void:
    if not multiplayer.is_server():
        return

    var sender_id: int = multiplayer.get_remote_sender_id()
    if sender_id <= 0:
        return
    var existing_sequence: int = int(peer_states.get(sender_id, {}).get("sequence", -1))
    if sequence < existing_sequence:
        return

    peer_states[sender_id] = {
        "sequence": sequence,
        "active": active,
        "downed": downed,
        "dimension": dimension,
        "dimension_instance_key": dimension_instance_key,
        "pocket_owner_key": pocket_owner_key,
        "position": position,
        "yaw": yaw,
        "pitch": pitch,
        "crouching": crouching,
        "grounded": grounded,
        "move_speed": move_speed,
        "under_water": under_water,
        "held_item_id": held_item_id,
        "action_state": action_state,
        "name": player_name,
        "player_key": player_key,
        "avatar_id": _normalize_avatar_id(avatar_id),
        "skin_color": skin_color,
        "breaking": breaking,
        "break_position": break_position,
        "break_block_id": break_block_id,
        "break_progress": break_progress,
    }
    _refresh_markers(peer_states, multiplayer.get_unique_id())


@rpc("any_peer", "call_remote", "reliable")
func submit_client_state_reliable(sequence: int, active: bool, downed: bool, dimension: int, dimension_instance_key: String, pocket_owner_key: String, position: Vector3, yaw: float, pitch: float, crouching: bool, grounded: bool, move_speed: float, under_water: bool, held_item_id: int, action_state: int, player_name: String, player_key: String, avatar_id: String, skin_color: Color, breaking: bool, break_position: Vector3i, break_block_id: int, break_progress: float) -> void:
    submit_client_state(sequence, active, downed, dimension, dimension_instance_key, pocket_owner_key, position, yaw, pitch, crouching, grounded, move_speed, under_water, held_item_id, action_state, player_name, player_key, avatar_id, skin_color, breaking, break_position, break_block_id, break_progress)


@rpc("any_peer", "call_remote", "reliable")
func request_debug_spawn(spawn_id: String, dimension_instance_key: String, spawn_origin: Vector3, look_direction: Vector3) -> void:
    if not multiplayer.is_server():
        return

    var sender_id: int = multiplayer.get_remote_sender_id()
    if sender_id <= 0:
        return
    if dimension_instance_key != get_active_dimension_instance_key():
        receive_debug_command_status.rpc_id(sender_id, "Spawn failed: join the host's current area first")
        return

    receive_debug_command_status.rpc_id(sender_id, _spawn_debug_entity_from_id(spawn_id, spawn_origin, look_direction))


@rpc("authority", "call_remote", "reliable")
func receive_debug_command_status(message: String) -> void:
    status_message = message
    _update_status_text()


@rpc("any_peer", "call_remote", "reliable")
func request_drop_item(item_data: PackedInt32Array, spawn_position: Vector3, launch_velocity: Vector3) -> void:
    if not multiplayer.is_server():
        return

    var item_state = _deserialize_item_state(item_data)
    if item_state == null:
        return

    var scene = load(DROPPED_ITEM_SCENE_PATH)
    if not (scene is PackedScene):
        return

    var dropped_item = scene.instantiate()
    if dropped_item == null:
        return

    get_tree().get_root().add_child(dropped_item)
    var drop_uuid: String = _assign_sync_uuid(dropped_item)
    dropped_item.delay_collect()
    dropped_item.delay_merge()
    dropped_item.global_position = spawn_position
    dropped_item.initialize(item_state)
    dropped_item.global_position = spawn_position
    dropped_item.velocity = launch_velocity
    sync_spawn_drop.rpc(drop_uuid, item_data, dropped_item.global_position, dropped_item.velocity, bool(dropped_item.can_collect))


@rpc("any_peer", "call_remote", "reliable")
func request_pickup_drop(item_uuid: String) -> void:
    if not multiplayer.is_server():
        return

    var sender_id: int = multiplayer.get_remote_sender_id()
    if sender_id <= 0:
        return

    var dropped_item = _find_host_drop_by_uuid(item_uuid)
    if dropped_item == null or dropped_item.item == null or not dropped_item.can_collect:
        return

    var item_data: PackedInt32Array = _serialize_item_state(dropped_item.item)
    dropped_item.collect()
    sync_remove_drop.rpc(item_uuid)
    receive_picked_item.rpc_id(sender_id, item_data)


@rpc("any_peer", "call_remote", "reliable")
func submit_guest_persistent_state(player_key: String, player_name: String, save_data: Dictionary) -> void:
    if not multiplayer.is_server() or player_key == "" or save_data.is_empty():
        return
    _store_guest_persistent_state(player_key, player_name, save_data)


@rpc("any_peer", "call_remote", "reliable")
func request_guest_persistent_state(player_key: String, player_name: String) -> void:
    if not multiplayer.is_server() or player_key == "":
        return

    var sender_id: int = multiplayer.get_remote_sender_id()
    if sender_id <= 0:
        return

    var guest_data: Dictionary = _get_guest_persistent_state(player_key)
    if guest_data.is_empty():
        Ref.save_file_manager.loaded_file.set_data("coop/players/%s/name" % player_key, player_name, true)
    receive_guest_persistent_state.rpc_id(sender_id, guest_data)


@rpc("authority", "call_remote", "reliable")
func receive_guest_persistent_state(save_data: Dictionary) -> void:
    if multiplayer.is_server():
        return
    _mark_host_contact()
    if save_data.is_empty():
        _initialize_new_guest_profile()
    else:
        _apply_received_guest_state(save_data)


@rpc("any_peer", "call_remote", "reliable")
func request_place_block(block_position: Vector3i, block_id: int) -> void:
    if not multiplayer.is_server():
        return

    var sender_id: int = multiplayer.get_remote_sender_id()
    if sender_id <= 0:
        return
    if not is_instance_valid(Ref.world) or not Ref.world.is_position_loaded(block_position):
        return

    _apply_network_place(block_position, block_id)
    sync_place_block.rpc(block_position, block_id)


@rpc("any_peer", "call_remote", "reliable")
func request_host_world_snapshot() -> void:
    if not multiplayer.is_server():
        return

    var sender_id: int = multiplayer.get_remote_sender_id()
    if sender_id <= 0:
        return

    _send_world_snapshot_to_peer.call_deferred(sender_id)


@rpc("any_peer", "call_remote", "reliable")
func request_dimension_world_snapshot(target_dimension: int, target_pocket_owner_key: String = "") -> void:
    if not multiplayer.is_server():
        return

    var sender_id: int = multiplayer.get_remote_sender_id()
    if sender_id <= 0:
        return

    _send_world_snapshot_to_peer.call_deferred(sender_id, target_dimension, target_pocket_owner_key, false)


@rpc("authority", "call_remote", "reliable")
func begin_host_world_snapshot(register_json: String, chunk_count: int, host_position: Vector3, follow_host_position: bool = true) -> void:
    if multiplayer.is_server():
        return

    _mark_host_contact()

    incoming_snapshot_register_json = register_json
    incoming_snapshot_chunk_count = chunk_count
    incoming_snapshot_chunks.clear()
    incoming_snapshot_host_position = host_position
    incoming_snapshot_follow_host_position = follow_host_position
    receiving_host_world = true
    status_message = "Receiving host world (%s chunks)" % chunk_count
    _update_status_text()


@rpc("authority", "call_remote", "reliable")
func host_world_snapshot_chunk(chunk_index: int, data: PackedByteArray) -> void:
    if multiplayer.is_server() or not receiving_host_world:
        return

    _mark_host_contact()

    incoming_snapshot_chunks[chunk_index] = data
    status_message = "Receiving host world (%s/%s)" % [incoming_snapshot_chunks.size(), incoming_snapshot_chunk_count]
    _update_status_text()


@rpc("authority", "call_remote", "reliable")
func finish_host_world_snapshot() -> void:
    if multiplayer.is_server() or not receiving_host_world:
        return

    _mark_host_contact()

    _apply_received_host_world.call_deferred()


@rpc("any_peer", "call_remote", "reliable")
func begin_world_patch(chunk_count: int) -> void:
    return


@rpc("any_peer", "call_remote", "reliable")
func world_patch_chunk(chunk_index: int, data: PackedByteArray) -> void:
    return


@rpc("any_peer", "call_remote", "reliable")
func finish_world_patch() -> void:
    return


func _relay_world_patch_to_matching_peers(world_patch: Dictionary, excluded_peer_id: int = -1) -> void:
    return


@rpc("authority", "call_remote", "reliable")
func sync_place_block(block_position: Vector3i, block_id: int) -> void:
    if multiplayer.is_server():
        return
    _mark_host_contact()
    if is_instance_valid(Ref.world) and Ref.world.is_position_loaded(block_position) and Ref.world.is_block_solid_at(block_position):
        return
    _apply_network_place(block_position, block_id)


@rpc("any_peer", "call_remote", "reliable")
func request_break_block(block_position: Vector3i, pickaxe: bool, axe: bool, shovel: bool, meat: bool, plant: bool) -> void:
    if not multiplayer.is_server():
        return

    var sender_id: int = multiplayer.get_remote_sender_id()
    if sender_id <= 0:
        return
    if not is_instance_valid(Ref.world) or not Ref.world.is_position_loaded(block_position):
        return

    var broken_block = Ref.world.get_block_type_at(block_position)
    if broken_block == null:
        return
    _apply_network_break(block_position)
    if broken_block != null:
        _spawn_break_drops_for_block(broken_block, block_position, pickaxe, axe, shovel, meat, plant)
    sync_break_block.rpc(block_position)


@rpc("any_peer", "call_remote", "reliable")
func request_water_cells(changes: Array) -> void:
    if not multiplayer.is_server():
        return

    _apply_network_water_cells(changes)
    sync_water_cells.rpc(changes)


@rpc("authority", "call_remote", "reliable")
func sync_water_cells(changes: Array) -> void:
    if multiplayer.is_server():
        return
    _mark_host_contact()
    _apply_network_water_cells(changes)


@rpc("any_peer", "call_remote", "reliable")
func request_fire_cell(block_position: Vector3i, fire_level: int) -> void:
    if not multiplayer.is_server():
        return

    _apply_network_fire_cell(block_position, fire_level)
    sync_fire_cell.rpc(block_position, fire_level)


@rpc("authority", "call_remote", "reliable")
func sync_fire_cell(block_position: Vector3i, fire_level: int) -> void:
    if multiplayer.is_server():
        return
    _mark_host_contact()
    _apply_network_fire_cell(block_position, fire_level)


@rpc("authority", "call_remote", "reliable")
func sync_world_changes(dimension_instance_key: String, block_changes: Array, fire_changes: Array) -> void:
    if multiplayer.is_server():
        return
    _mark_host_contact()
    if dimension_instance_key != get_active_dimension_instance_key():
        return

    _apply_network_block_changes(block_changes)
    for entry in fire_changes:
        if not (entry is Array) or entry.size() < 2:
            continue
        _apply_network_fire_cell(entry[0], int(entry[1]))


@rpc("any_peer", "call_remote", "reliable")
func request_foliage_break(block_position: Vector3i) -> void:
    if not multiplayer.is_server():
        return

    var block: Block = Ref.world.get_block_type_at(block_position)
    if block == null or not block.foliage:
        return

    _apply_network_break(block_position)
    if block.can_drop:
        var new_state := ItemState.new()
        new_state.initialize(block)
        new_state.count = 1
        _spawn_network_item(new_state, block_position)
    sync_break_block.rpc(block_position)


@rpc("authority", "call_remote", "reliable")
func sync_break_block(block_position: Vector3i) -> void:
    if multiplayer.is_server():
        return
    _mark_host_contact()
    _apply_network_break(block_position)


@rpc("authority", "call_remote", "reliable")
func sync_spawn_drop(drop_uuid: String, item_data: PackedInt32Array, drop_position: Vector3, drop_velocity: Vector3, can_collect: bool = true) -> void:
    if multiplayer.is_server():
        return
    _mark_host_contact()

    var item_state = _deserialize_item_state(item_data)
    if item_state == null:
        return
    if client_collected_drop_uuids.has(drop_uuid):
        return

    var dropped_item = synced_dropped_items.get(drop_uuid, null)
    if not is_instance_valid(dropped_item):
        dropped_item = _find_existing_drop_by_uuid(drop_uuid)
    if not is_instance_valid(dropped_item):
        dropped_item = _find_matching_predicted_drop(item_state, drop_position)
        if is_instance_valid(dropped_item):
            _configure_client_synced_drop(dropped_item, drop_uuid)
    if not is_instance_valid(dropped_item):
        dropped_item = _spawn_client_synced_drop(drop_uuid, item_state)
    if not is_instance_valid(dropped_item):
        return

    synced_dropped_items[drop_uuid] = dropped_item
    _apply_client_drop_snapshot(dropped_item, item_state, drop_position, drop_velocity, can_collect)


@rpc("authority", "call_remote", "reliable")
func sync_remove_drop(drop_uuid: String) -> void:
    if multiplayer.is_server():
        return
    _mark_host_contact()

    client_collected_drop_uuids[drop_uuid] = Time.get_ticks_msec()
    var dropped_item = synced_dropped_items.get(drop_uuid, null)
    if not is_instance_valid(dropped_item):
        dropped_item = _find_existing_drop_by_uuid(drop_uuid)
    if is_instance_valid(dropped_item):
        dropped_item.set_meta("coop_pickup_pending_request", false)
        if dropped_item is DroppedItem and dropped_item.state == DroppedItem.COLLECTED:
            dropped_item.queue_free()
        elif dropped_item.has_method("collect"):
            dropped_item.collect()
        else:
            dropped_item.queue_free()
    synced_dropped_items.erase(drop_uuid)


@rpc("authority", "call_remote", "unreliable")
func server_world_state(sequence: int, drop_snapshots: Array, entity_snapshots: Array = []) -> void:
    if multiplayer.is_server() or receiving_host_world or _is_local_world_authority():
        return
    _mark_host_contact()
    _apply_client_world_state(sequence, drop_snapshots, entity_snapshots)


@rpc("authority", "call_remote", "reliable")
func receive_picked_item(item_data: PackedInt32Array) -> void:
    if multiplayer.is_server():
        return

    _mark_host_contact() 

    var item_state = _deserialize_item_state(item_data)
    if item_state == null or not _can_sample_player():
        return
    if _consume_pending_pickup_receipt(item_state):
        return

    var pickup_behavior = Ref.player.get_node_or_null("%PickUpItems")
    if pickup_behavior != null:
        pickup_behavior.accept_item(item_state, true)


@rpc("authority", "call_remote", "reliable")
func send_tiamana_reward(amount: int) -> void:
    if multiplayer.is_server():
        return
    _mark_host_contact()
    if not _can_sample_player():
        return
    var level_node = Ref.player.get_node_or_null("%Level")
    if level_node != null and level_node.has_method("give_tiamana"):
        level_node.give_tiamana(amount, 1)


@rpc("authority", "call_remote", "reliable")
func receive_remote_player_attack(attacker_uuid: String, attacker_position: Vector3, attacker_velocity: Vector3, damage_position: Vector3, damage: int, knockback_strength: float, fly_strength: float, fire_aspect: bool) -> void:
    if multiplayer.is_server():
        return

    _mark_host_contact()

    if not _can_sample_player() or Ref.player.dead or Ref.player.disabled or Ref.player.direct_damage_cooldown:
        return

    var attacker = _find_client_synced_entity_by_uuid(attacker_uuid) if attacker_uuid != "" else null

    var horizontal_kb: Vector3 = Ref.player.global_position - attacker_position
    horizontal_kb.y = 0.0
    if not horizontal_kb.is_zero_approx():
        horizontal_kb = horizontal_kb.normalized()

    Ref.player.knockback_velocity += 0.45 * attacker_velocity + horizontal_kb * knockback_strength
    Ref.player.knockback_velocity.y += knockback_strength * Ref.player.jump_modifier * fly_strength * (0.5 if not Ref.player.is_on_floor() else 1.0)
    Ref.player.attacked(attacker, maxi(1, damage))
    play_local_damage_feedback(maxi(1, damage))

    if Ref.player.has_node("%Bleed"):
        var target_to_attacker: Vector3 = (attacker_position - Ref.player.global_position).normalized()
        Ref.player.get_node("%Bleed").bleed(damage_position, target_to_attacker, maxi(1, damage))

    if fire_aspect and Ref.player.has_node("%Burn"):
        Ref.player.get_node("%Burn").ignite()


@rpc("authority", "call_remote", "reliable")
func sync_host_respawn_state(respawning: bool) -> void:
    if multiplayer.is_server():
        return
    _mark_host_contact()
    remote_host_respawning = respawning
    if respawning:
        status_message = "Host respawning"
    elif status_message == "Host respawning":
        status_message = "Host respawned"
    _update_status_text()


@rpc("authority", "call_remote", "unreliable")
func server_snapshot(snapshot_sequence: int, snapshot: Array) -> void:
    if multiplayer.is_server():
        return

    _mark_host_contact()
    if snapshot_sequence < last_received_host_snapshot_sequence:
        return
    last_received_host_snapshot_sequence = snapshot_sequence

    peer_states.clear()
    for entry in snapshot:
        if not (entry is Array) or entry.size() < 22:
            continue

        peer_states[int(entry[0])] = {
            "active": bool(entry[1]),
            "downed": bool(entry[2]),
            "dimension": int(entry[3]),
            "dimension_instance_key": str(entry[4]),
            "pocket_owner_key": str(entry[5]),
            "position": entry[6],
            "yaw": float(entry[7]),
            "pitch": float(entry[8]),
            "crouching": bool(entry[9]),
            "grounded": bool(entry[10]),
            "move_speed": float(entry[11]),
            "held_item_id": int(entry[12]),
            "action_state": int(entry[13]),
            "name": str(entry[14]),
            "player_key": str(entry[15]),
            "avatar_id": _normalize_avatar_id(str(entry[16])),
            "skin_color": entry[17] if entry[17] is Color else Color.WHITE,
            "breaking": bool(entry[18]),
            "break_position": entry[19],
            "break_block_id": int(entry[20]),
            "break_progress": float(entry[21]),
        }

    if not multiplayer.is_server() and not receiving_host_world and _can_sample_player() and peer_states.has(1):
        var host_instance_key: String = str(peer_states[1].get("dimension_instance_key", ""))
        if host_instance_key != "" and host_instance_key != get_active_dimension_instance_key():
            status_message = "Resyncing host world"
            _update_status_text()
            request_host_world_snapshot.rpc_id(1)
            return

    _refresh_markers(peer_states, multiplayer.get_unique_id())


@rpc("authority", "call_remote", "reliable")
func server_snapshot_reliable(snapshot_sequence: int, snapshot: Array) -> void:
    server_snapshot(snapshot_sequence, snapshot)
