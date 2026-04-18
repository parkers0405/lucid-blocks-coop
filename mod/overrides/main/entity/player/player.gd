class_name Player extends Entity


@export_group("Movement")
@export var sprint_speed_multiplier: float = 1.3
@export var jump_speed_multiplier: float = 1.1
@export var crouch_speed_multiplier: float = 0.3
@export var fly_speed_multiplier: float = 8
@export var fly_impulse: float = 9.0
@export var minimum_sprint_speed: float = 1.0

@export_group("Animation")
@export var crouch_time: float = 0.125
@export var spring_fov_time: float = 0.25

@export_group("Other")
@export var spawn_invincibility_time: float = 5.0
@export var fov_spring_scale: float = 1.15
@export var sprint_difference_threshold: float = 0.1
@export var starter_kit: Array[Item]

const DOUBLE_TAP_SPRINT_WINDOW_MSEC: int = 260
const GROUND_SPRINT_SPEED_MULTIPLIER: float = 1.22
const SPRINT_CAMERA_BOB_FREQUENCY: float = 13.0
const SPRINT_CAMERA_BOB_X: float = 0.018
const SPRINT_CAMERA_BOB_Y: float = 0.028
const SPRINT_CAMERA_BOB_ROLL_DEG: float = 1.35
const CAMERA_MODE_FIRST_PERSON: int = 0
const CAMERA_MODE_THIRD_PERSON_BACK: int = 1
const CAMERA_MODE_THIRD_PERSON_FRONT: int = 2
const THIRD_PERSON_BACK_DISTANCE: float = 3.2
const THIRD_PERSON_FRONT_DISTANCE: float = 2.4
const THIRD_PERSON_CAMERA_COLLISION_MARGIN: float = 0.12
const FIRST_PERSON_ZOOM_FOV_RATIO: float = 0.32
const FIRST_PERSON_ZOOM_IN_TIME: float = 0.11
const FIRST_PERSON_ZOOM_OUT_TIME: float = 0.15
const FIRST_PERSON_ZOOM_SENSITIVITY_SCALE: float = 0.42
const CAMERA_OVERHAUL_STRAFE_ROLL_DEG: float = 4.8
const CAMERA_OVERHAUL_FORWARD_PITCH_DEG: float = 2.4
const CAMERA_OVERHAUL_VERTICAL_PITCH_DEG: float = 1.7
const CAMERA_OVERHAUL_TURN_ROLL_INTENSITY_DEG: float = 3.0
const CAMERA_OVERHAUL_TURN_ROLL_ACCUMULATION: float = 1.35
const CAMERA_OVERHAUL_TURN_ROLL_DECAY: float = 9.0
const CAMERA_OVERHAUL_HORIZONTAL_SMOOTHING: float = 8.0
const CAMERA_OVERHAUL_VERTICAL_SMOOTHING: float = 10.0
const CAMERA_OVERHAUL_IDLE_SWAY_PITCH_DEG: float = 0.2
const CAMERA_OVERHAUL_IDLE_SWAY_ROLL_DEG: float = 0.35
const CAMERA_OVERHAUL_IDLE_SWAY_DELAY_SEC: float = 0.2
const CAMERA_OVERHAUL_IDLE_SWAY_FADE_IN_SEC: float = 2.4
const CAMERA_OVERHAUL_IDLE_SWAY_FADE_OUT_SEC: float = 0.35
const CAMERA_OVERHAUL_ZOOM_INTENSITY_SCALE: float = 0.6


var sprint_toggle: bool = false
var crouch_toggle: bool = false
const COOP_INTERACT_RELEASE_GRACE_SEC: float = 0.12

var left_handed: bool = false
var invert_mouse_y: bool = false
var might_double_jump: bool = false
var mouse_sensitivity: float = 0.01
var fov: float = 86
var controller_camera_sensitivity: float = 1.0
var show_hand_setting: bool = true


var consumed_actions: Array[String] = []
var flying: bool = false
var fly_enabled: bool = false
var is_sprinting_requested: bool = false
var is_croucing_requested: bool = false
var is_sprinting: bool = false
var is_crouching: bool = false:
    set(val):
        is_crouching = val
        crouching_changed.emit(val)
var can_switch_hotbar: bool = true
var attack_used: bool = false
var is_breaking_block: bool = false
var current_structure: Structure = null
var can_interact_with_block: bool = false:
    set(val):
        can_interact_with_block = val
        can_interact_with_block_changed.emit(val)
var can_interact_using_item: bool = false:
    set(val):
        can_interact_using_item = val
        can_interact_using_item_changed.emit(val)


var camera_height: float = 0.0
var camera_fov: float = 0.0
var camera_pitch: float = 0.0


var teleport_location: Vector3
var teleport: bool = false


var push_bodies: Dictionary[Entity, bool]
var coop_interact_release_grace_timer: float = 0.0
var last_forward_press_msec: int = 0
var double_tap_sprint_requested: bool = false
var sprint_camera_bob_phase: float = 0.0
var sprint_camera_bob_weight: float = 0.0
var camera_mode: int = CAMERA_MODE_FIRST_PERSON
var local_avatar_marker: Node3D = null
var first_person_zoom_amount: float = 0.0
var camera_overhaul_prev_yaw: float = 0.0
var camera_overhaul_prev_pitch: float = 0.0
var camera_overhaul_forward_pitch_offset: float = 0.0
var camera_overhaul_vertical_pitch_offset: float = 0.0
var camera_overhaul_strafe_roll_offset: float = 0.0
var camera_overhaul_turn_roll_target: float = 0.0
var camera_overhaul_idle_sway_weight: float = 0.0
var camera_overhaul_last_action_time_sec: float = 0.0

signal structure_changed(new_structure: Structure)
signal can_interact_with_block_changed(value: bool)
signal can_interact_using_item_changed(value: bool)
signal crouching_changed(value: bool)


func _ready() -> void :
    super._ready()



    remove_from_group("preserve_but_delete_on_unload")
    remove_from_group("preserve")

    Ref.save_file_manager.settings_updated.connect(_on_settings_updated)
    _on_settings_updated()

    held_item_index_changed.connect(_on_held_item_index_changed)

    %PushArea3D.body_entered.connect(_on_body_entered)
    %PushArea3D.body_exited.connect(_on_body_exited)

    %Burn.burning_started.connect(_on_burning_started)
    %Burn.burning_stopped.connect(_on_burning_stopped)

    %FlyTimer.timeout.connect(_on_fly_timeout)
    %SpawnInvincibilityTimer.timeout.connect(_on_spawn_invincibility_timeout)

    damage_taken.connect(_on_damage_taken)

    Ref.main.new_game_loaded.connect(_on_new_game)
    camera_pitch = %Camera3D.rotation.x
    _reset_camera_overhaul_state()
    _apply_camera_mode_visuals()
    call_deferred("_ensure_local_avatar_marker")
    call_deferred("_apply_avatar_sound_overrides")
    call_deferred("_apply_avatar_hand_color")
    print("Player ready.")


func _get_coop_manager() -> Node:
    var ref: Node = get_node_or_null("/root/Ref")
    if ref != null and ref.get("coop_manager") != null:
        return ref.get("coop_manager")
    return null


var _avatar_voice_player: AudioStreamPlayer
var _avatar_voice_streams: Dictionary = {}
var _avatar_voice_cooldown: float = 0.0
const AVATAR_VOICE_CHANCES: Dictionary = {
    "jump": 0.005,
    "hurt": 0.015,
    "attack": 0.008,
    "death": 0.25,
    "fall": 0.01,
}
const AVATAR_VOICE_COOLDOWNS: Dictionary = {
    "jump": 20.0,
    "hurt": 12.0,
    "attack": 15.0,
    "death": 10.0,
    "fall": 15.0,
}


func _apply_avatar_sound_overrides() -> void:
    var coop_manager: Node = _get_coop_manager()
    if coop_manager == null or not coop_manager.has_method("get_local_avatar_id"):
        return
    var avatar_id: String = coop_manager.call("get_local_avatar_id")
    var AvatarRegistryScript = load("res://coop_mod/avatar_registry.gd")
    if AvatarRegistryScript == null:
        return
    var entry: Dictionary = AvatarRegistryScript.get_avatar_entry(avatar_id)
    var sounds_config: Dictionary = entry.get("sounds", {})
    if sounds_config.is_empty():
        return

    # Don't replace base sounds - add a separate voice player for occasional character lines
    _avatar_voice_player = AudioStreamPlayer.new()
    _avatar_voice_player.bus = "SFX"
    _avatar_voice_player.volume_db = -6.0
    add_child(_avatar_voice_player)

    for action_name in sounds_config.keys():
        var paths: Array = sounds_config[action_name]
        var streams: Array = []
        for path in paths:
            var stream = load(str(path))
            if stream is AudioStream:
                streams.append(stream)
        if not streams.is_empty():
            _avatar_voice_streams[action_name] = streams

    # Hook into damage signal for hurt/death voice lines
    if not damage_taken.is_connected(_on_avatar_damage_voice):
        damage_taken.connect(_on_avatar_damage_voice)
    print("[avatar] Loaded %d voice categories for %s" % [_avatar_voice_streams.size(), avatar_id])


func _play_avatar_voice(action: String) -> void:
    if _avatar_voice_player == null or _avatar_voice_cooldown > 0.0:
        return
    if not _avatar_voice_streams.has(action):
        return
    var chance: float = AVATAR_VOICE_CHANCES.get(action, 0.15)
    if randf() > chance:
        return
    var streams: Array = _avatar_voice_streams[action]
    if streams.is_empty():
        return
    _avatar_voice_player.stream = streams[randi() % streams.size()]
    _avatar_voice_player.play()
    _avatar_voice_cooldown = AVATAR_VOICE_COOLDOWNS.get(action, 2.0)


func _on_avatar_damage_voice(_damage: int) -> void:
    if health <= 0:
        _play_avatar_voice("death")
    else:
        _play_avatar_voice("hurt")


func _apply_avatar_hand_color() -> void:
    var hand_node: Node = get_node_or_null("%PlayerHand")
    if hand_node != null and hand_node.has_method("set_hand_color"):
        hand_node.call("set_hand_color")
    else:
        # Retry after a short delay - hand might not be ready yet
        await get_tree().create_timer(0.5).timeout
        hand_node = get_node_or_null("%PlayerHand")
        if hand_node != null and hand_node.has_method("set_hand_color"):
            hand_node.call("set_hand_color")


func _set_camera_pitch(new_pitch: float) -> void:
    camera_pitch = clampf(new_pitch, -deg_to_rad(90), deg_to_rad(90))
    %Camera3D.rotation.x = camera_pitch


func _is_third_person_camera_mode() -> bool:
    return camera_mode != CAMERA_MODE_FIRST_PERSON


func _is_first_person_camera_mode() -> bool:
    return camera_mode == CAMERA_MODE_FIRST_PERSON


func _get_camera_mode_label() -> String:
    match camera_mode:
        CAMERA_MODE_THIRD_PERSON_BACK:
            return "Third Person Back"
        CAMERA_MODE_THIRD_PERSON_FRONT:
            return "Third Person Front"
        _:
            return "First Person"


func _apply_camera_mode_visuals() -> void:
    if not is_node_ready():
        return

    var show_first_person_visuals: bool = not _is_third_person_camera_mode()
    %PlayerHand.visible = show_hand_setting and show_first_person_visuals

    var arm: Node3D = get_node_or_null("%Arm") as Node3D
    if arm != null:
        arm.visible = show_first_person_visuals

    _sync_held_item_visibility()


func _sync_held_item_visibility() -> void:
    if is_instance_valid(held_item):
        held_item.visible = _is_third_person_camera_mode()


func _cycle_camera_mode() -> void:
    camera_mode = (camera_mode + 1) % 3
    if not _is_first_person_camera_mode():
        first_person_zoom_amount = 0.0
    _reset_camera_overhaul_state()
    _apply_camera_mode_visuals()
    print("Camera mode: %s" % _get_camera_mode_label())


func _ensure_local_avatar_marker() -> void:
    if is_instance_valid(local_avatar_marker):
        return

    var marker_script = load("res://coop_mod/remote_player_marker.gd")
    if not (marker_script is GDScript):
        return

    local_avatar_marker = marker_script.new()
    local_avatar_marker.name = "LocalAvatarMarker"
    add_child(local_avatar_marker)

    if local_avatar_marker.has_method("setup"):
        local_avatar_marker.call("setup", multiplayer.get_unique_id())
    if local_avatar_marker.has_method("set_avatar_sounds_enabled"):
        local_avatar_marker.call("set_avatar_sounds_enabled", false)
    if local_avatar_marker.has_method("set_label_enabled"):
        local_avatar_marker.call_deferred("set_label_enabled", false)


func _get_local_avatar_id_for_marker() -> String:
    var coop_manager: Node = _get_coop_manager()
    if coop_manager != null and coop_manager.has_method("get_local_avatar_id"):
        return str(coop_manager.call("get_local_avatar_id"))
    return "default_blocky"


func _get_local_skin_color_for_marker() -> Color:
    if Ref.save_file_manager == null or Ref.save_file_manager.settings_file == null:
        return Color.WHITE
    return Ref.save_file_manager.settings_file.get_data("skin_modulate", Color.WHITE)


func _get_local_action_state() -> int:
    if %PlayerHand.current_hand == null:
        return 0
    return int(%PlayerHand.current_hand.state)


func _sync_local_avatar_marker() -> void:
    _ensure_local_avatar_marker()
    if not is_instance_valid(local_avatar_marker):
        return

    if local_avatar_marker.has_method("set_display_name"):
        local_avatar_marker.call("set_display_name", "")
    if local_avatar_marker.has_method("set_avatar_id"):
        local_avatar_marker.call("set_avatar_id", _get_local_avatar_id_for_marker())
    if local_avatar_marker.has_method("set_skin_color"):
        local_avatar_marker.call("set_skin_color", _get_local_skin_color_for_marker())
    if local_avatar_marker.has_method("set_held_item_id"):
        var held_item_id: int = held_item.item.id if is_instance_valid(held_item) and held_item.item != null else -1
        local_avatar_marker.call("set_held_item_id", held_item_id)
    if local_avatar_marker.has_method("apply_state"):
        local_avatar_marker.call(
            "apply_state",
            not dead and _is_third_person_camera_mode(),
            global_position,
            %RotationPivot.rotation.y,
            camera_pitch,
            is_crouching,
            is_on_floor(),
            Vector3(velocity.x, 0.0, velocity.z).length(),
            _get_local_action_state()
        )


func _resolve_camera_world_position(pivot_position: Vector3) -> Vector3:
    if camera_mode == CAMERA_MODE_FIRST_PERSON or not is_inside_tree() or get_world_3d() == null:
        return pivot_position

    var desired_distance: float = THIRD_PERSON_BACK_DISTANCE if camera_mode == CAMERA_MODE_THIRD_PERSON_BACK else THIRD_PERSON_FRONT_DISTANCE
    var camera_forward: Vector3 = -%Camera3D.global_transform.basis.z.normalized()
    var desired_position: Vector3 = pivot_position - camera_forward * desired_distance

    var exclude: Array = [get_rid()]
    var interact_area: CollisionObject3D = get_node_or_null("%InteractArea3D") as CollisionObject3D
    if interact_area != null:
        exclude.append(interact_area.get_rid())

    var query := PhysicsRayQueryParameters3D.create(pivot_position, desired_position)
    query.exclude = exclude
    query.collide_with_areas = false

    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return desired_position

    var resolved_position: Vector3 = hit.position + (pivot_position - desired_position).normalized() * THIRD_PERSON_CAMERA_COLLISION_MARGIN
    if pivot_position.distance_to(resolved_position) <= THIRD_PERSON_CAMERA_COLLISION_MARGIN:
        return pivot_position
    return resolved_position


func _is_first_person_zoom_requested() -> bool:
    return movement_enabled and MouseHandler.fully_captured and _is_first_person_camera_mode() and Input.is_key_pressed(KEY_C)


func _reset_camera_overhaul_state() -> void:
    camera_overhaul_prev_yaw = %RotationPivot.rotation.y if is_node_ready() else 0.0
    camera_overhaul_prev_pitch = camera_pitch
    camera_overhaul_forward_pitch_offset = 0.0
    camera_overhaul_vertical_pitch_offset = 0.0
    camera_overhaul_strafe_roll_offset = 0.0
    camera_overhaul_turn_roll_target = 0.0
    camera_overhaul_idle_sway_weight = 0.0
    camera_overhaul_last_action_time_sec = Time.get_ticks_msec() / 1000.0


func _get_first_person_zoom_weight() -> float:
    return ease(first_person_zoom_amount, -2.0)


func _get_camera_overhaul_blend(speed: float, delta: float) -> float:
    return clampf(1.0 - exp(-speed * delta), 0.0, 1.0)


func _get_camera_overhaul_turn_eased(x: float) -> float:
    return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


func _get_first_person_camera_overhaul_rotation(delta: float) -> Vector3:
    if not _is_first_person_camera_mode():
        camera_overhaul_prev_yaw = %RotationPivot.rotation.y
        camera_overhaul_prev_pitch = camera_pitch
        return Vector3.ZERO

    var basis: Basis = %RotationPivot.global_transform.basis
    var right: Vector3 = basis.x.normalized()
    var forward: Vector3 = (-basis.z).normalized()
    var forward_velocity: float = velocity.dot(forward)
    var strafe_velocity: float = velocity.dot(right)
    var speed_base: float = maxf(speed * GROUND_SPRINT_SPEED_MULTIPLIER, 0.001)
    var yaw_delta: float = angle_difference(camera_overhaul_prev_yaw, %RotationPivot.rotation.y)
    var pitch_delta: float = camera_pitch - camera_overhaul_prev_pitch
    var now_sec: float = Time.get_ticks_msec() / 1000.0

    var is_player_active: bool = Vector3(velocity.x, 0.0, velocity.z).length() > 0.03 \
        or absf(velocity.y) > 0.03 \
        or absf(yaw_delta) > 0.0005 \
        or absf(pitch_delta) > 0.0005 \
        or _is_first_person_zoom_requested() \
        or Input.is_action_pressed("attack") \
        or Input.is_action_pressed("interact")
    if is_player_active:
        camera_overhaul_last_action_time_sec = now_sec

    var horizontal_blend: float = _get_camera_overhaul_blend(CAMERA_OVERHAUL_HORIZONTAL_SMOOTHING, delta)
    var vertical_blend: float = _get_camera_overhaul_blend(CAMERA_OVERHAUL_VERTICAL_SMOOTHING, delta)
    var normalized_forward_velocity: float = clampf(forward_velocity / speed_base, -1.4, 1.4)
    var normalized_strafe_velocity: float = clampf(strafe_velocity / speed_base, -1.4, 1.4)
    var normalized_vertical_velocity: float = clampf(velocity.y / maxf(jump_impulse * 1.25, 0.001), -2.0, 2.0)

    camera_overhaul_forward_pitch_offset = lerpf(
        camera_overhaul_forward_pitch_offset,
        deg_to_rad(normalized_forward_velocity * CAMERA_OVERHAUL_FORWARD_PITCH_DEG),
        horizontal_blend
    )
    camera_overhaul_vertical_pitch_offset = lerpf(
        camera_overhaul_vertical_pitch_offset,
        deg_to_rad(normalized_vertical_velocity * CAMERA_OVERHAUL_VERTICAL_PITCH_DEG),
        vertical_blend
    )
    camera_overhaul_strafe_roll_offset = lerpf(
        camera_overhaul_strafe_roll_offset,
        deg_to_rad(-normalized_strafe_velocity * CAMERA_OVERHAUL_STRAFE_ROLL_DEG),
        horizontal_blend
    )

    camera_overhaul_turn_roll_target = lerpf(
        camera_overhaul_turn_roll_target,
        0.0,
        clampf(delta * CAMERA_OVERHAUL_TURN_ROLL_DECAY, 0.0, 1.0)
    )
    camera_overhaul_turn_roll_target = clampf(
        camera_overhaul_turn_roll_target + yaw_delta * CAMERA_OVERHAUL_TURN_ROLL_ACCUMULATION,
        -1.0,
        1.0
    )

    var idle_target: float = 1.0 if (now_sec - camera_overhaul_last_action_time_sec) >= CAMERA_OVERHAUL_IDLE_SWAY_DELAY_SEC else 0.0
    var idle_fade_time: float = CAMERA_OVERHAUL_IDLE_SWAY_FADE_IN_SEC if idle_target > camera_overhaul_idle_sway_weight else CAMERA_OVERHAUL_IDLE_SWAY_FADE_OUT_SEC
    camera_overhaul_idle_sway_weight = move_toward(camera_overhaul_idle_sway_weight, idle_target, delta / maxf(idle_fade_time, 0.001))
    var idle_sway_strength: float = pow(camera_overhaul_idle_sway_weight, 3.0)
    var sway_pitch: float = deg_to_rad((sin(now_sec * 0.77) + sin(now_sec * 1.19 + 1.7)) * 0.5 * CAMERA_OVERHAUL_IDLE_SWAY_PITCH_DEG * idle_sway_strength)
    var sway_roll: float = deg_to_rad((sin(now_sec * 0.71 + 0.8) + cos(now_sec * 0.97 + 2.1)) * 0.5 * CAMERA_OVERHAUL_IDLE_SWAY_ROLL_DEG * idle_sway_strength)

    var turn_roll_strength: float = _get_camera_overhaul_turn_eased(absf(camera_overhaul_turn_roll_target))
    var turn_roll_sign: float = 0.0 if is_zero_approx(camera_overhaul_turn_roll_target) else (1.0 if camera_overhaul_turn_roll_target > 0.0 else -1.0)
    var turn_roll: float = deg_to_rad(CAMERA_OVERHAUL_TURN_ROLL_INTENSITY_DEG * turn_roll_strength * turn_roll_sign)
    var zoom_intensity_scale: float = lerpf(1.0, CAMERA_OVERHAUL_ZOOM_INTENSITY_SCALE, _get_first_person_zoom_weight())

    camera_overhaul_prev_yaw = %RotationPivot.rotation.y
    camera_overhaul_prev_pitch = camera_pitch

    return Vector3(
        (camera_overhaul_forward_pitch_offset + camera_overhaul_vertical_pitch_offset + sway_pitch) * zoom_intensity_scale,
        0.0,
        (camera_overhaul_strafe_roll_offset + turn_roll + sway_roll) * zoom_intensity_scale
    )


func _get_camera_look_sensitivity_scale() -> float:
    if not _is_first_person_camera_mode():
        return 1.0
    return lerpf(1.0, FIRST_PERSON_ZOOM_SENSITIVITY_SCALE, _get_first_person_zoom_weight())


func _on_settings_updated() -> void :
    fov = int(Ref.save_file_manager.settings_file.get_data("fov", 86))
    sprint_toggle = Ref.save_file_manager.settings_file.get_data("sprint_toggle", false)
    crouch_toggle = Ref.save_file_manager.settings_file.get_data("crouch_toggle", false)
    left_handed = Ref.save_file_manager.settings_file.get_data("left_hand", false)
    invert_mouse_y = Ref.save_file_manager.settings_file.get_data("invert_look_y", false)
    mouse_sensitivity = (0.001 + Ref.save_file_manager.settings_file.get_data("camera_sensitivity", 14) / 1000.0)
    controller_camera_sensitivity = 0.25 + 1.75 * Ref.save_file_manager.settings_file.get_data("controller_camera_sensitivity", 14) / 14.0

    %Camera3D.shake_enabled = Ref.save_file_manager.settings_file.get_data("screen_shake", true)
    show_hand_setting = Ref.save_file_manager.settings_file.get_data("show_hand", true)
    _apply_camera_mode_visuals()

    hand.position.x = abs(hand.position.x) * (-1.0 if left_handed else 1.0)


func consume_actions() -> void :
    consumed_actions.clear()
    for action in ["jump", "crouch", "attack", "interact"]:
        if Input.is_action_pressed(action):
            consumed_actions.append(action)


func is_action_pressed_safe(action: String) -> bool:
    if action in consumed_actions:
        if Input.is_action_just_released(action):
            consumed_actions.erase(action)
        return false
    return Input.is_action_pressed(action)


func _get_coop_interact_pressed(raw_interact_pressed: bool, delta: float) -> bool:
    if multiplayer.is_server() or not is_interacting() or %PlayerHand.current_hand == null:
        coop_interact_release_grace_timer = 0.0
        return raw_interact_pressed
    if %PlayerHand.current_hand.state != PlayerHandVariant.State.INTERACT_SUSTAIN:
        coop_interact_release_grace_timer = 0.0
        return raw_interact_pressed

    if raw_interact_pressed:
        coop_interact_release_grace_timer = COOP_INTERACT_RELEASE_GRACE_SEC
        return true

    if coop_interact_release_grace_timer > 0.0:
        coop_interact_release_grace_timer = maxf(coop_interact_release_grace_timer - delta, 0.0)
        return true

    return false


func _on_fly_timeout() -> void :
    might_double_jump = false


func _on_spawn_invincibility_timeout() -> void :
    invincible_temporary = false


func make_invincible_temporary() -> void :
    invincible_temporary = true
    %SpawnInvincibilityTimer.start(spawn_invincibility_time)


func remove_temporary_invincible() -> void :
    %SpawnInvincibilityTimer.stop()
    invincible_temporary = false


func _on_damage_taken(_damage: int) -> void :
    %Camera3D.camera_shake(0.2, 0.04)


func _on_burning_started() -> void :
    %EntityFireVisual.enter()


func _on_burning_stopped() -> void :
    %EntityFireVisual.exit()


func _on_body_entered(body: PhysicsBody3D) -> void :
    push_bodies[body as Entity] = true


func _on_body_exited(body: PhysicsBody3D) -> void :
    push_bodies.erase(body)


func _get_selected_hotbar_item_state() -> ItemState:
    if held_item_inventory == null or not is_instance_valid(held_item_inventory):
        return null
    if held_item_index < 0 or held_item_index >= held_item_inventory.items.size():
        return null
    return held_item_inventory.items[held_item_index]


func _sync_player_hand_visual() -> void:
    if not is_node_ready():
        return
    var player_hand: PlayerHand = get_node_or_null("%PlayerHand") as PlayerHand
    if player_hand == null:
        return
    player_hand.switch_item(held_item, _get_selected_hotbar_item_state())
    _sync_held_item_visibility()


func _on_held_item_index_changed() -> void :
    call_deferred("_sync_player_hand_visual")


func _on_held_item_inventory_item_slot_changed(_inventory: Inventory, index: int) -> void :
    super._on_held_item_inventory_item_slot_changed(_inventory, index)
    if index == held_item_index:
        call_deferred("_sync_player_hand_visual")


func _on_instant_interact_impulse() -> void :
    %PlayerHand.interact()


func _process(delta: float) -> void :
    if disabled:
        return

    if _avatar_voice_cooldown > 0.0:
        _avatar_voice_cooldown -= delta


    if Ref.main.debug and Input.is_action_just_pressed("debug_jump"):
        global_position.y += 256 if not is_crouching else -256

    if not Ref.world.is_position_loaded(global_position):
        return


    var local_movement_enabled: bool = movement_enabled and MouseHandler.fully_captured
    var joy_input: Vector2 = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
    if local_movement_enabled and is_processing_input() and joy_input != Vector2.ZERO:
        var look_sensitivity_scale: float = _get_camera_look_sensitivity_scale()
        %RotationPivot.rotate_y( - joy_input.x * controller_camera_sensitivity * look_sensitivity_scale * delta)
        var y_direction: float = -1.0 if not invert_mouse_y else 1.0
        _set_camera_pitch(camera_pitch + y_direction * joy_input.y * controller_camera_sensitivity * look_sensitivity_scale * delta)

    check_water()
    camera_process(delta)
    _sync_local_avatar_marker()
    update_walk_animation()


    if not local_movement_enabled:
        if %BreakBlocks.breaking:
            %BreakBlocks.break_block_stop()
        var keep_interacting: bool = _get_coop_interact_pressed(is_action_pressed_safe("interact"), delta)
        if is_interacting() and not keep_interacting:
            held_item.interact_end()
            if %PlayerHand.current_hand.state == PlayerHandVariant.State.INTERACT_SUSTAIN:
                %PlayerHand.interact_sustain_end()
    else:

        var data: Dictionary = get_interact_data()

        interaction_process(data, delta)
        attack_process(data)

    update_pointer_visual.call_deferred()
    hand_process()
    %PlayerHand.position = ( %Camera3D.unproject_position( %Hand.global_position) - %PlayerHand.scale * %PlayerHand.offset)


func _physics_process(delta: float) -> void :
    var local_movement_enabled: bool = movement_enabled and MouseHandler.fully_captured

    gravity_direction_multiplier = -1 if Ref.main.upside_down else 1

    if disabled or not Ref.world.is_position_loaded(global_position):
        return

    update_structure()
    super._physics_process(delta)
    if is_future_position_loaded(delta):
        move_and_slide()

    if not dead and not invincible and (Ref.world.current_dimension == LucidBlocksWorld.Dimension.CHALLENGE or Ref.world.current_dimension == LucidBlocksWorld.Dimension.FIRMAMENT) and global_position.y < -128:
        health -= 1
    var input: Vector2 = Input.get_vector("left", "right", "up", "down") if local_movement_enabled else Vector2()
    var movement_dir: Vector3 = %RotationPivot.global_transform.basis * Vector3(input.x, 0, input.y)
    var moving_forward: bool = input.y < -0.5 and absf(input.x) <= 0.9

    var hold_sprint_requested: bool = is_action_pressed_safe("sprint")
    if not sprint_toggle:
        if not moving_forward or is_action_pressed_safe("down") or not local_movement_enabled:
            double_tap_sprint_requested = false
        is_sprinting_requested = hold_sprint_requested or double_tap_sprint_requested
    if not crouch_toggle:
        is_croucing_requested = is_action_pressed_safe("crouch")
    if fly_enabled and local_movement_enabled and might_double_jump and is_action_pressed_safe("jump") and Input.is_action_just_pressed("jump"):
        might_double_jump = false
        %FlyTimer.stop()
        flying = not flying
    if not fly_enabled:
        flying = false

    is_sprinting = not is_interacting() \
        and local_movement_enabled \
        and is_sprinting_requested \
        and moving_forward \
        and not is_croucing_requested \
        and (flying or Vector3(movement_velocity.x, 0.0, movement_velocity.z).length() >= minimum_sprint_speed)

    is_crouching = is_croucing_requested and not is_sprinting and local_movement_enabled

    var target_speed: float = speed * speed_modifier
    var accel: float = ground_accel * accel_modifier

    if is_crouching:
        target_speed = speed * crouch_speed_multiplier * speed_modifier

    if not is_on_floor() and not is_crouching:
        accel = air_accel * accel_modifier * air_accel_modifier
        target_speed *= jump_speed_multiplier

    if is_on_ceiling() and gravity_direction_multiplier * movement_velocity.y > 0:
        movement_velocity.y = 0

    if flying:
        target_speed = speed * fly_speed_multiplier * speed_modifier
        if is_sprinting:
            target_speed *= sprint_speed_multiplier
        static_gravity_modifier = 0.0
    else:
        if is_sprinting:
            target_speed *= GROUND_SPRINT_SPEED_MULTIPLIER
        static_gravity_modifier = 1.0

    default_entity_movement(
        delta, movement_dir, accel, target_speed * speed_modifier, local_movement_enabled and is_on_floor() and is_action_pressed_safe("jump"), local_movement_enabled and is_action_pressed_safe("jump"), local_movement_enabled and is_action_pressed_safe("crouch")
    )

    if is_action_pressed_safe("jump") and Input.is_action_just_pressed("jump"):
        %FlyTimer.start()
        might_double_jump = true

    if flying and local_movement_enabled:
        fly_process()

    if is_crouching and is_on_floor():
        crouch_snap(delta)

    push_process(delta)



func _input(event: InputEvent) -> void :
    if disabled:
        return

    if can_switch_hotbar and MouseHandler.fully_captured:
        var new_index: int = held_item_index
        for i in range(6):
            if event.is_action_pressed("hotbar_%d" % (i + 1), false):
                new_index = i
        if event.is_action_pressed("hotbar_next", false):
            new_index += 1
        if event.is_action_pressed("hotbar_back", false):
            new_index -= 1
        if new_index < 0:
            new_index += 6
        new_index = new_index % 6

        if held_item_index != new_index:
            hold_item(new_index)

    var local_movement_enabled: bool = movement_enabled and MouseHandler.fully_captured
    if local_movement_enabled and is_instance_valid(held_item) and event.is_action_pressed("drop_item", false):
        %DropItems.drop_and_remove_from_inventory( %Hotbar, held_item_index)

    if local_movement_enabled and event is InputEventKey:
        var key_event := event as InputEventKey
        if key_event.pressed and not key_event.echo and key_event.keycode == KEY_V:
            _cycle_camera_mode()
            get_viewport().set_input_as_handled()
            return

    if event is InputEventMouseMotion and local_movement_enabled:
        var look_sensitivity_scale: float = _get_camera_look_sensitivity_scale()
        %RotationPivot.rotate_y( - event.relative.x * mouse_sensitivity * look_sensitivity_scale)

        var y_direction: float = -1.0 if not invert_mouse_y else 1.0
        _set_camera_pitch(camera_pitch + y_direction * event.relative.y * mouse_sensitivity * look_sensitivity_scale)

    if sprint_toggle and event.is_action_pressed("sprint", false):
        is_sprinting_requested = not is_sprinting_requested

    if local_movement_enabled and event.is_action_pressed("up", false):
        var is_repeat_press: bool = event is InputEventKey and (event as InputEventKey).echo
        if not is_repeat_press:
            var now_msec: int = Time.get_ticks_msec()
            if now_msec - last_forward_press_msec <= DOUBLE_TAP_SPRINT_WINDOW_MSEC:
                double_tap_sprint_requested = true
            last_forward_press_msec = now_msec

    if crouch_toggle and event.is_action_pressed("crouch", false):
        is_croucing_requested = not is_croucing_requested




func initialize() -> void :
    %BreakBlocks.break_block_stop()
    %Drown.reset()
    %Burn.reset()

    force_check_update = true
    invincible = Ref.main.creative
    is_sprinting_requested = false
    is_croucing_requested = false
    is_sprinting = false
    double_tap_sprint_requested = false
    last_forward_press_msec = 0
    is_crouching = false
    under_water = false
    head_under_water = false
    feet_under_water = false
    attack_used = false
    is_breaking_block = false
    dead = false
    camera_height = 0.0
    camera_fov = 0.0
    camera_pitch = 0.0
    static_speed_modifier = 1.0
    static_accel_modifier = 1.0
    static_gravity_modifier = 1.0
    glider_gravity_modifier = 1.0
    glider_speed_modifier = 1.0
    sprint_camera_bob_phase = 0.0
    sprint_camera_bob_weight = 0.0
    first_person_zoom_amount = 0.0
    _reset_camera_overhaul_state()
    first_frame = true
    current_biome = null
    push_bodies.clear()
    hand_process()


func _on_new_game() -> void :
    show_hand_setting = Ref.save_file_manager.settings_file.get_data("show_hand", true)
    first_person_zoom_amount = 0.0
    _reset_camera_overhaul_state()
    _apply_camera_mode_visuals()
    %HarmCover.visible = true
    health = 10
    max_health = 10
    hate = 1
    lust = 3
    faith = 2

    if Ref.main.debug and not Ref.main.creative and Ref.save_file_manager.loaded_file_register.get_data("starter_kit", false):
        for i in range(len(starter_kit)):
            var new_item: ItemState = ItemState.new()
            new_item.initialize(starter_kit[i])
            new_item.count = ItemMap.map(new_item.id).stack_size
            held_item_inventory.set_item(i, new_item)


func save_file(file: SaveFile) -> void :
    super.preserve_save(file, "player")

    file.set_data("node/player/global_position", global_position, false)
    file.set_data("node/player/camera_angle", camera_pitch, false)
    file.set_data("node/player/camera_mode", camera_mode, false)
    file.set_data("node/player/flying", flying, true)


func load_file(file: SaveFile) -> void :
    super.preserve_load(file, "player")

    _set_camera_pitch(file.get_data("node/player/camera_angle", camera_pitch, false))
    camera_mode = int(file.get_data("node/player/camera_mode", camera_mode, false))
    camera_mode = clampi(camera_mode, CAMERA_MODE_FIRST_PERSON, CAMERA_MODE_THIRD_PERSON_FRONT)
    first_person_zoom_amount = 0.0
    _reset_camera_overhaul_state()
    global_position = file.get_data("node/player/global_position", Vector3(0, 0, 0), false)
    flying = file.get_data("node/player/flying", false, true)
    _apply_camera_mode_visuals()

func die() -> void :
    if disabled or dead:
        return

    if Ref.main.in_challenge or Ref.main.in_ending:
        Ref.game_menu.deactivate()
        disabled = true
        get_tree().paused = true
        Ref.audio_manager.fade_out_sfx()

        await Ref.trans.open_scary()

        if Ref.main.in_challenge:
            print("End challenge...")
            Ref.main.end_challenge(false)
        if Ref.main.in_ending:
            print("End ending...")
            Ref.main.end_ending(false)
        Ref.plot_manager.remove_cutscene()
        revive()

        if Ref.coop_manager != null:
            await Ref.coop_manager._travel_group_to_dimension_async(int(LucidBlocksWorld.Dimension.NARAKA), true, false)
        else:
            await Ref.main.teleport_to_dimension(LucidBlocksWorld.Dimension.NARAKA, true)
    else:
        druj += 1
        dead = true


func revive() -> void :
    health = max_health
    movement_velocity = Vector3()
    rope_velocity = Vector3()
    gravity_velocity = Vector3()
    knockback_velocity = Vector3()
    velocity = Vector3()
    last_velocity_y = 0
    has_endure = true
    %Burn.burning = false
    %Drown.air = %Drown.max_air


func get_look_direction() -> Vector3:
    if %AimRayCast3D.is_colliding():
        return ( %AimRayCast3D.get_collision_point() - hand.global_position).normalized()
    return ( %AimRayCast3D.to_global( %AimRayCast3D.target_position) - hand.global_position).normalized()



func hand_process() -> void :
    var current_hand: PlayerHandVariant = %PlayerHand.current_hand
    if %BreakBlocks.breaking and current_hand.state != PlayerHandVariant.State.HIT_SUSTAIN:
        current_hand.hit_sustain_start()
    if not %BreakBlocks.breaking and current_hand.state == PlayerHandVariant.State.HIT_SUSTAIN:
        current_hand.hit_sustain_end()



func camera_process(delta: float) -> void :
    var zoom_requested: bool = _is_first_person_zoom_requested()
    var zoom_target: float = 1.0 if zoom_requested else 0.0
    var zoom_time: float = FIRST_PERSON_ZOOM_IN_TIME if zoom_requested else FIRST_PERSON_ZOOM_OUT_TIME
    first_person_zoom_amount = move_toward(first_person_zoom_amount, zoom_target, delta / maxf(zoom_time, 0.001))

    if is_sprinting:
        camera_fov += delta / spring_fov_time
    else:
        camera_fov -= delta / spring_fov_time
    camera_fov = clamp(camera_fov, 0.0, 1.0)

    var base_fov: float = lerp(fov, fov * fov_spring_scale, ease(camera_fov, -2.0))
    if _is_first_person_camera_mode():
        %Camera3D.fov = lerpf(base_fov, base_fov * FIRST_PERSON_ZOOM_FOV_RATIO, _get_first_person_zoom_weight())
    else:
        %Camera3D.fov = base_fov

    if is_crouching:
        camera_height += delta / crouch_time
    else:
        camera_height -= delta / crouch_time

    camera_height = clamp(camera_height, 0.0, 1.0)
    var camera_pivot_position: Vector3 = lerp(%HeadPointNormal.position, %HeadPointCrouch.position, ease(camera_height, -2.0))
    var horizontal_speed: float = Vector3(velocity.x, 0.0, velocity.z).length()
    var sprint_bob_target: float = 1.0 if is_sprinting and is_on_floor() and horizontal_speed > minimum_sprint_speed else 0.0
    sprint_camera_bob_weight = move_toward(sprint_camera_bob_weight, sprint_bob_target, delta * 6.0)
    if sprint_camera_bob_weight > 0.001:
        var sprint_ratio: float = clampf(horizontal_speed / maxf(speed * GROUND_SPRINT_SPEED_MULTIPLIER, 0.001), 0.0, 1.0)
        sprint_camera_bob_phase = wrapf(sprint_camera_bob_phase + delta * SPRINT_CAMERA_BOB_FREQUENCY * lerpf(0.92, 1.1, sprint_ratio), 0.0, TAU)

    camera_pivot_position.x += cos(sprint_camera_bob_phase * 0.5) * SPRINT_CAMERA_BOB_X * sprint_camera_bob_weight
    camera_pivot_position.y += absf(sin(sprint_camera_bob_phase)) * SPRINT_CAMERA_BOB_Y * sprint_camera_bob_weight
    %CameraPivot.position = camera_pivot_position

    var first_person_camera_overhaul_rotation: Vector3 = _get_first_person_camera_overhaul_rotation(delta)
    var camera_roll: float = deg_to_rad(sin(sprint_camera_bob_phase * 0.5) * SPRINT_CAMERA_BOB_ROLL_DEG * sprint_camera_bob_weight)
    var camera_x_rotation: float = camera_pitch + first_person_camera_overhaul_rotation.x
    var camera_y_rotation: float = 0.0
    camera_roll += first_person_camera_overhaul_rotation.z
    if camera_mode == CAMERA_MODE_THIRD_PERSON_FRONT:
        camera_x_rotation = -camera_pitch
        camera_y_rotation = PI
        camera_roll = 0.0
    elif camera_mode == CAMERA_MODE_THIRD_PERSON_BACK:
        camera_roll = 0.0

    %Camera3D.rotation = Vector3(
        camera_x_rotation,
        camera_y_rotation,
        camera_roll
    )
    %Camera3D.global_position = _resolve_camera_world_position(%CameraPivot.global_position)

    %Arm.position = %CameraPivot.position
    var arm_pitch: float = camera_pitch
    var arm_roll: float = 0.0
    if _is_first_person_camera_mode():
        arm_pitch = camera_x_rotation
        arm_roll = camera_roll
    %Arm.rotation = Vector3(arm_pitch, %RotationPivot.rotation.y, arm_roll)



func attack_process(data: Dictionary) -> void :
    var attack_pressed: bool = is_action_pressed_safe("attack")
    if not is_interacting():
        if attack_pressed and Input.is_action_just_pressed("attack"):
            if "ball_target" in data and data.ball_target.can_parry:
                attack_used = true
                data.ball_target.apply_impulse(velocity * 0.25 + get_look_direction() * 28.0)
                data.ball_target.attacked()
                %WhiffPlayer.play()
                _play_avatar_voice("attack")
                %PlayerHand.current_hand.hit()
            if "target" in data:
                attack_used = true
                %WhiffPlayer.play()
                _play_avatar_voice("attack")
                %Attack.attack(data.target, data.get("attack_position", %InteractRayCast3D.get_collision_point()))
                %PlayerHand.current_hand.hit()
                %Camera3D.camera_shake()
            elif "target_position" in data:
                pass
            else:
                %WhiffPlayer.play()
                _play_avatar_voice("attack")
                %PlayerHand.hit()

        var debug_always_breaking: bool = false
        if not attack_used and not "target" in data and not %BreakBlocks.breaking:



            var invisible_block_seen: bool = false
            var potential_cells: Array[Vector3] = BlockMath.visit_all(data.interact_begin, data.interact_end)
            for place_position in potential_cells:
                place_position = place_position.floor()
                if not Ref.world.is_position_loaded(place_position):
                    continue
                if not Ref.world.is_block_solid_at(place_position) and is_instance_valid(Ref.world.get_living_block_at(place_position)):
                    if attack_pressed and Input.is_action_just_pressed("attack"):
                        %BreakBlocks.break_block_instant(Vector3i(place_position))
                    invisible_block_seen = true
                    break
            if (debug_always_breaking or attack_pressed) and not invisible_block_seen and "target_position" in data:
                is_breaking_block = true
                %BreakBlocks.break_block_start(data.target_position)
        if %BreakBlocks.breaking and ( not (debug_always_breaking or attack_pressed) or not "target_position" in data or not Vector3i(data.target_position) == %BreakBlocks.active_position):
            is_breaking_block = false
            %BreakBlocks.break_block_stop()
        if Input.is_action_just_released("attack"):
            attack_used = false
        if not attack_pressed:
            is_breaking_block = false



func interaction_process(data: Dictionary, delta: float) -> void :
    if disabled:
        return
    var interact_pressed: bool = _get_coop_interact_pressed(is_action_pressed_safe("interact"), delta)

    can_interact_with_block = ("target_position" in data and is_instance_valid(Ref.world.get_living_block_at(data.target_position)) and Ref.world.get_living_block_at(data.target_position).can_currently_interact(self))
    can_interact_using_item = is_instance_valid(held_item) and held_item.can_interact(data)


    if not is_breaking_block and not is_crouching and interact_pressed and Input.is_action_just_pressed("interact") and can_interact_with_block:
        var living_block: LivingBlock = Ref.world.get_living_block_at(data.target_position) as LivingBlock
        living_block.interact(self)

    elif interact_pressed and Input.is_action_just_pressed("interact") and not is_interacting() and is_instance_valid(held_item):
        var interaction_type: int = held_item.interaction_type
        var success: bool = can_interact_using_item and await held_item.interact(true, data)
        if success:
            if is_breaking_block:
                %BreakBlocks.break_block_stop()

            if interaction_type == 0:
                %PlayerHand.interact()
            else:
                %PlayerHand.interact_sustain_start()

    elif not interact_pressed and is_interacting():
        if %PlayerHand.current_hand.state == PlayerHandVariant.State.INTERACT_SUSTAIN:
            %PlayerHand.interact_sustain_end()
        held_item.interact_end()


    if is_interacting() and not held_item.holding_animation and %PlayerHand.current_hand.state == PlayerHandVariant.State.INTERACT_SUSTAIN:
        %PlayerHand.interact_sustain_end()


func fly_process() -> void :
    gravity_velocity.y = 0
    if is_action_pressed_safe("jump"):
        movement_velocity.y = (gravity_direction_multiplier * fly_impulse * (sprint_speed_multiplier if is_sprinting else 1.0))
    elif is_action_pressed_safe("crouch"):
        movement_velocity.y = - gravity_direction_multiplier * fly_impulse
    else:
        movement_velocity.y = 0


func push_process(delta: float) -> void :
    for body in push_bodies:
        if not is_instance_valid(body) or body == self:
            continue
        var distance: float = body.global_position.distance_squared_to(global_position)
        if distance > 0.75:
            continue
        var t: float = pow(1.0 - distance / 0.75, 2)
        body.knockback_velocity += (8 * (velocity * 0.1 + 16.0 * t * (body.global_position - global_position).normalized()) * delta * clamp(weight / body.weight, 0.0, 12.0))


func crouch_snap(delta: float) -> void :
    %FloorShapeCast3D.global_position = global_position + Vector3(movement_velocity.x * delta, 0, 0)
    %FloorShapeCast3D.force_shapecast_update()
    if not %FloorShapeCast3D.is_colliding():
        movement_velocity.x = 0

    %FloorShapeCast3D.global_position = global_position + Vector3(0, 0, movement_velocity.z * delta)
    %FloorShapeCast3D.force_shapecast_update()
    if not %FloorShapeCast3D.is_colliding():
        movement_velocity.z = 0



func update_walk_animation() -> void :
    %AnimationPlayer.speed_scale = 0.5 if is_crouching else (1.45 if is_sprinting else 1.25)
    if Vector3(velocity.x, 0, velocity.z).length() > 0.1 and not in_air:
        var animation_name: String = "run" if is_sprinting and %AnimationPlayer.has_animation("run") else "walk"
        var animation: Animation = %AnimationPlayer.get_animation(animation_name)
        if animation != null and animation.loop_mode == Animation.LOOP_NONE:
            animation.loop_mode = Animation.LOOP_LINEAR
        if %AnimationPlayer.current_animation != animation_name or not %AnimationPlayer.is_playing():
            %AnimationPlayer.play(animation_name, 0.12)
    else:
        %AnimationPlayer.stop()



func update_pointer_visual() -> void :
    var data: Dictionary = get_interact_data(true)
    %BlockOutline.visible = false
    if "target_position" in data:
        %BlockOutline.global_position = data.target_position + Vector3(0.5, 0.5, 0.5)
        %BlockOutline.visible = true



func update_structure() -> void :
    var structure: Structure = Ref.world.get_nearest_structure(global_position)
    if not Ref.world.is_within_structure(global_position):
        structure = null
    if structure != current_structure:
        current_structure = structure
        structure_changed.emit(current_structure)



func _resolve_interact_owner_from_collider(collider: Object):
    if not is_instance_valid(collider):
        return null
    if collider.has_meta("coop_hit_owner"):
        var coop_hit_owner = collider.get_meta("coop_hit_owner")
        if is_instance_valid(coop_hit_owner) and (coop_hit_owner is Ball or coop_hit_owner is Heart or coop_hit_owner is Entity):
            return coop_hit_owner
    if collider is Ball or collider is Heart or collider is Entity:
        return collider

    var current: Node = collider as Node
    while current != null:
        if current.has_meta("coop_hit_owner"):
            var current_coop_hit_owner = current.get_meta("coop_hit_owner")
            if is_instance_valid(current_coop_hit_owner) and (current_coop_hit_owner is Ball or current_coop_hit_owner is Heart or current_coop_hit_owner is Entity):
                return current_coop_hit_owner
        if current is Ball or current is Heart or current is Entity:
            return current
        if current.owner is Ball or current.owner is Heart or current.owner is Entity:
            return current.owner
        current = current.get_parent()
    return null


func get_interact_data(skip_look: bool = false) -> Dictionary:
    var data: Dictionary = {}

    if skip_look:
        if %LookRayCast3D.is_colliding():
            var collider: Object = %LookRayCast3D.get_collider()
            var look_target = _resolve_interact_owner_from_collider(collider)
            if look_target is Entity:
                var look_entity := look_target as Entity
                if is_instance_valid(look_entity) and not look_entity.disabled and not look_entity.dead:
                    look_entity.looked_at_by_player()

    data.interact_begin = %InteractRayCast3D.global_position
    data.interact_end = %InteractRayCast3D.to_global( %InteractRayCast3D.target_position)
    data.interact_normal = %InteractRayCast3D.get_collision_normal()
    data.interact_end_adjacent = ( %InteractRayCast3D.get_collision_point() + %InteractRayCast3D.get_collision_normal() * 0.5)




    var non_block_position: Vector3
    var non_block_collision: bool = false
    for i in range(2):
        %InteractRayCast3D.set_collision_mask_value(1, i == 1)
        %InteractRayCast3D.force_raycast_update()
        if %InteractRayCast3D.is_colliding():
            data.interact_end = %InteractRayCast3D.get_collision_point()

            var collider: Object = %InteractRayCast3D.get_collider()
            var resolved_target = _resolve_interact_owner_from_collider(collider)
            var collider_name: String = collider.name if collider is Node else str(collider)
            var resolved_name: String = resolved_target.name if resolved_target is Node else str(resolved_target)
            data["debug_collider"] = "%s:%s" % [collider.get_class(), collider_name]
            data["debug_resolved"] = "%s:%s" % [resolved_target.get_class(), resolved_name] if is_instance_valid(resolved_target) else "<none>"
            if resolved_target is Ball or resolved_target is Heart:
                data.ball_target = resolved_target
                non_block_position = data.interact_end
                non_block_collision = true
                data.attack_position = data.interact_end
            elif resolved_target is Entity:
                data.target = resolved_target as Entity
                non_block_position = data.interact_end
                non_block_collision = true
                data.attack_position = data.interact_end
            else:

                if (
                    non_block_collision
                    and (non_block_position.distance_to(data.interact_end) < 0.001 or ( %InteractRayCast3D.global_position.distance_squared_to(non_block_position) < %InteractRayCast3D.global_position.distance_squared_to(data.interact_end)))
                ):
                    data.interact_end = non_block_position
                else:
                    data.erase("target")
                    data.erase("ball_target")

                    var target_position: Vector3 = ( %InteractRayCast3D.get_collision_point() - %InteractRayCast3D.get_collision_normal() * 0.5).floor()
                    if Ref.world.is_position_loaded(target_position) and Ref.world.is_block_solid_at(target_position):
                        data.target_position = target_position
                        data.target_position_adjacent = (data.target_position + %InteractRayCast3D.get_collision_normal())

    if not data.has("target") and not data.has("ball_target") and Ref.coop_manager != null and not multiplayer.is_server():
        var fallback_target = Ref.coop_manager.find_client_ray_attack_target(data.interact_begin, data.interact_end)
        if is_instance_valid(fallback_target):
            data.erase("target_position")
            data.erase("target_position_adjacent")
            data.target = fallback_target
            data.attack_position = Ref.coop_manager.get_client_attack_hit_position(fallback_target, data.interact_begin, data.interact_end)
            data["debug_resolved"] = "fallback:%s:%s" % [fallback_target.get_class(), fallback_target.name if fallback_target is Node else str(fallback_target)]

    return data
