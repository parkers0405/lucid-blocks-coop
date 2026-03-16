class_name EntityInterp extends RefCounted


const SNAP_POSITION_DIST_SQ: float = 49.0
const SNAP_YAW_DEG: float = 65.0
const POSITION_BLEND_SPEED: float = 16.0
const ROTATION_BLEND_SPEED: float = 14.0
const COMPONENT_BLEND_SPEED: float = 18.0
const POSITION_EPSILON_SQ: float = 0.0004


var authoritative_position: Vector3 = Vector3.ZERO
var authoritative_yaw_deg: float = 0.0
var authoritative_total_velocity: Vector3 = Vector3.ZERO
var authoritative_movement_velocity: Vector3 = Vector3.ZERO
var authoritative_gravity_velocity: Vector3 = Vector3.ZERO
var authoritative_knockback_velocity: Vector3 = Vector3.ZERO
var authoritative_rope_velocity: Vector3 = Vector3.ZERO
var last_server_time: float = 0.0
var last_seq: int = -1
var has_baseline: bool = false


func push_snapshot(
	server_time: float,
	seq: int,
	position: Vector3,
	yaw_deg: float,
	total_velocity: Vector3,
	movement_velocity: Vector3 = Vector3.ZERO,
	gravity_velocity: Vector3 = Vector3.ZERO,
	knockback_velocity: Vector3 = Vector3.ZERO,
	rope_velocity: Vector3 = Vector3.ZERO
) -> void:
	if has_baseline and seq <= last_seq:
		return

	last_seq = seq
	last_server_time = server_time
	authoritative_position = position
	authoritative_yaw_deg = yaw_deg
	authoritative_total_velocity = total_velocity
	authoritative_movement_velocity = movement_velocity
	authoritative_gravity_velocity = gravity_velocity
	authoritative_knockback_velocity = knockback_velocity
	authoritative_rope_velocity = rope_velocity
	has_baseline = true


func snap_entity(entity) -> void:
	if entity == null or not has_baseline:
		return

	entity.global_position = authoritative_position
	var rotation_pivot: Node3D = entity.get_node_or_null("%RotationPivot") as Node3D
	if rotation_pivot != null:
		rotation_pivot.rotation.y = deg_to_rad(authoritative_yaw_deg)
	else:
		entity.rotation.y = deg_to_rad(authoritative_yaw_deg)

	_apply_component_velocities(entity, 1.0)


func update_entity(entity, delta: float) -> void:
	if entity == null or not has_baseline:
		return

	var entity_yaw_deg: float = authoritative_yaw_deg
	var rotation_pivot: Node3D = entity.get_node_or_null("%RotationPivot") as Node3D
	if rotation_pivot != null:
		entity_yaw_deg = rad_to_deg(rotation_pivot.rotation.y)
	else:
		entity_yaw_deg = rad_to_deg(entity.rotation.y)

	var position_error: Vector3 = authoritative_position - entity.global_position
	var position_error_sq: float = position_error.length_squared()
	var yaw_error_deg: float = absf(wrapf(authoritative_yaw_deg - entity_yaw_deg, -180.0, 180.0))

	if position_error_sq >= SNAP_POSITION_DIST_SQ or yaw_error_deg >= SNAP_YAW_DEG:
		snap_entity(entity)
		return

	var position_alpha: float = 1.0 - exp(-POSITION_BLEND_SPEED * delta)
	if position_error_sq > POSITION_EPSILON_SQ:
		entity.global_position = entity.global_position.lerp(authoritative_position, position_alpha)

	var rotation_alpha: float = 1.0 - exp(-ROTATION_BLEND_SPEED * delta)
	if rotation_pivot != null:
		rotation_pivot.rotation.y = lerp_angle(rotation_pivot.rotation.y, deg_to_rad(authoritative_yaw_deg), rotation_alpha)
	else:
		entity.rotation.y = lerp_angle(entity.rotation.y, deg_to_rad(authoritative_yaw_deg), rotation_alpha)

	var component_alpha: float = 1.0 - exp(-COMPONENT_BLEND_SPEED * delta)
	_apply_component_velocities(entity, component_alpha)


func _apply_component_velocities(entity, alpha: float) -> void:
	if entity == null:
		return

	if entity is Entity:
		entity.movement_velocity = entity.movement_velocity.lerp(authoritative_movement_velocity, alpha)
		entity.gravity_velocity = entity.gravity_velocity.lerp(authoritative_gravity_velocity, alpha)
		entity.knockback_velocity = entity.knockback_velocity.lerp(authoritative_knockback_velocity, alpha)
		entity.rope_velocity = entity.rope_velocity.lerp(authoritative_rope_velocity, alpha)
		entity.velocity = entity.movement_velocity + entity.gravity_velocity + entity.knockback_velocity + entity.rope_velocity
		return

	if "velocity" in entity:
		entity.velocity = entity.velocity.lerp(authoritative_total_velocity, alpha)
