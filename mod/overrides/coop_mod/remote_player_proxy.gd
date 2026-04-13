extends "res://main/entity/player/player.gd"
class_name RemotePlayerProxy


const STAND_HEAD_HEIGHT: float = 1.45
const CROUCH_HEAD_HEIGHT: float = 1.1


var grounded: bool = true
var crouching: bool = false
var _last_position: Vector3 = Vector3.ZERO
var _last_update_msec: int = 0
var _target_position: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _target_downed: bool = false
var _target_grounded: bool = true
var _target_under_water: bool = false
var _target_crouching: bool = false
var _has_pending_state: bool = false


func _apply_targetable_collision(enabled: bool) -> void:
	collision_layer = 2 if enabled else 0
	var interact_area := get_node_or_null("RotationPivot/InteractArea3D") as Area3D
	if interact_area != null:
		interact_area.collision_layer = 4098 if enabled else 0
		interact_area.collision_mask = 0


func _ready() -> void:
	visible = false
	collision_layer = 2
	collision_mask = 0
	disabled = false
	dead = false
	invincible = true
	invincible_temporary = true
	movement_enabled = false
	can_rename = false
	disabled_by_visibility = false
	checks_for_water = false
	first_frame = false
	health = max_health
	under_water = false
	head_under_water = false
	feet_under_water = false
	is_crouching = false
	direct_damage_cooldown = false
	velocity = Vector3.ZERO
	movement_velocity = Vector3.ZERO
	gravity_velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	rope_velocity = Vector3.ZERO
	push_bodies = {}

	if not is_instance_valid(head):
		head = get_node_or_null("RotationPivot/Head") as Marker3D
	if not is_instance_valid(hand):
		hand = get_node_or_null("RotationPivot/Hand") as Marker3D
	if not is_instance_valid(rotation_pivot):
		rotation_pivot = get_node_or_null("RotationPivot") as Node3D

	remove_from_group("save")
	remove_from_group("preserve")
	remove_from_group("preserve_but_delete_on_unload")
	add_to_group("delete_on_quit")

	var visible_enabler := get_node_or_null("VisibleOnScreenEnabler3D") as VisibleOnScreenEnabler3D
	if visible_enabler != null:
		visible_enabler.enable_node_path = ""
		visible_enabler.process_mode = Node.PROCESS_MODE_DISABLED

	var interact_area := get_node_or_null("RotationPivot/InteractArea3D") as Area3D
	if interact_area != null:
		interact_area.monitoring = false
		interact_area.monitorable = true
		interact_area.collision_layer = 4098
		interact_area.collision_mask = 0
		interact_area.set_meta("coop_proxy_owner", self)

	_apply_crouching(false)
	_apply_targetable_collision(true)

	var direct_damage_timer := get_node_or_null("DirectDamageTimer") as Timer
	if direct_damage_timer != null:
		if not direct_damage_timer.timeout.is_connected(_on_direct_damage_timeout):
			direct_damage_timer.timeout.connect(_on_direct_damage_timeout)
		direct_damage_timer.stop()

	_target_position = global_position
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	set_physics_process(true)
	set_process_input(false)
	set_process_unhandled_input(false)


func apply_remote_state(state: Dictionary) -> void:
	var position: Vector3 = state.get("position", Vector3.ZERO)
	var now_msec: int = Time.get_ticks_msec()
	if _last_update_msec > 0:
		var delta_sec: float = maxf(float(now_msec - _last_update_msec) / 1000.0, 0.001)
		velocity = (position - _last_position) / delta_sec
	else:
		velocity = Vector3.ZERO
	_last_position = position
	_last_update_msec = now_msec

	_target_position = position
	_target_yaw = float(state.get("yaw", 0.0))
	_target_downed = bool(state.get("downed", false))
	_target_grounded = bool(state.get("grounded", true))
	_target_under_water = bool(state.get("under_water", false))
	_target_crouching = bool(state.get("crouching", false))
	_has_pending_state = true


func _physics_process(delta: float) -> void:
	if not _has_pending_state and _last_update_msec <= 0:
		return

	var desired_position: Vector3 = _target_position
	var displacement: Vector3 = desired_position - global_position
	var step_delta: float = maxf(delta, 0.001)
	velocity = displacement / step_delta

	dead = false
	disabled = _target_downed
	_apply_targetable_collision(not _target_downed)
	grounded = _target_grounded
	under_water = _target_under_water
	movement_velocity = Vector3(velocity.x, 0.0, velocity.z)
	gravity_velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	rope_velocity = Vector3.ZERO

	crouching = _target_crouching or _target_downed
	_apply_crouching(crouching)

	if displacement.length_squared() > 0.0:
		if displacement.length() > 8.0:
			global_position = desired_position
			if has_method("force_update_transform"):
				force_update_transform()
		else:
			move_and_collide(displacement)

	var horizontal_speed: float = Vector3(movement_velocity.x, 0.0, movement_velocity.z).length()
	is_sprinting = horizontal_speed > maxf(minimum_sprint_speed, speed * 1.1)

	if is_instance_valid(rotation_pivot):
		rotation_pivot.rotation.y = _target_yaw

	_has_pending_state = false


func _apply_crouching(value: bool) -> void:
	crouching = value
	is_crouching = value
	if is_instance_valid(head):
		head.position.y = CROUCH_HEAD_HEIGHT if value else STAND_HEAD_HEIGHT


func begin_direct_damage_cooldown(duration: float = 0.33) -> void:
	direct_damage_cooldown = true
	var direct_damage_timer := get_node_or_null("DirectDamageTimer") as Timer
	if direct_damage_timer != null:
		direct_damage_timer.start(duration)


func _on_direct_damage_timeout() -> void:
	direct_damage_cooldown = false


func update_walk_animation() -> void:
	# Remote proxies do not have the local first-person AnimationPlayer tree.
	return
