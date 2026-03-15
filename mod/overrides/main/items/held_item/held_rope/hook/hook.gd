class_name Hook extends Node3D

@export var retract_distance_threshold: float = 0.5

signal retracted
signal hooked

var retracting: bool = false
var shooting: bool = true
var static_hook: bool = false
var dynamic_hook: bool = false
var hook_entity: Entity
var hook_owner: Entity

var velocity: Vector3
var sticky_node: Node3D
var sticky_node_normal: Node3D

var base_speed: float

# Safety: limit how long the hook can fly without hitting anything
var _shoot_lifetime: float = 0.0
const MAX_SHOOT_LIFETIME: float = 2.0


func hook() -> void :
	var new_sparks: GPUParticles3D = %Sparks.duplicate()
	get_tree().get_root().add_child(new_sparks)
	new_sparks.global_position = global_position
	new_sparks.finished.connect(new_sparks.queue_free)
	new_sparks.emitting = true

	var new_player: AudioStreamPlayer3D = %HookPlayer.duplicate()
	get_tree().get_root().add_child(new_player)
	new_player.global_position = global_position
	new_player.finished.connect(new_player.queue_free)
	new_player.play()

	shooting = false
	hooked.emit()
	velocity = Vector3()


func _physics_process(delta: float) -> void :
	if retracting:
		var before_position: Vector3 = global_position
		global_position += (2.0 * base_speed * (hook_owner.hand.global_position - global_position).normalized() * delta)
		var after_position: Vector3 = global_position

		if after_position.distance_to(hook_owner.hand.global_position) < retract_distance_threshold:
			retracted.emit()

		elif (hook_owner.hand.global_position - before_position).normalized().dot((hook_owner.hand.global_position - after_position).normalized()) < 0.0:
			retracted.emit()
	elif dynamic_hook:
		if is_instance_valid(sticky_node) and is_instance_valid(hook_entity) and not hook_entity.dead:
			global_position = sticky_node.global_position
			SpatialMath.look_at( %RotationPivot, sticky_node_normal.global_position)
	elif shooting and not static_hook:
		# Safety timeout: if the hook has been shooting for too long, force retract
		_shoot_lifetime += delta
		if _shoot_lifetime > MAX_SHOOT_LIFETIME:
			retracting = true
			return

		%SnapChecker.target_position = %SnapChecker.to_local(global_position + velocity * delta)
		%SnapChecker.force_raycast_update()

		if %SnapChecker.is_colliding():
			global_position = %SnapChecker.get_collision_point()

			SpatialMath.look_at_local( %RotationPivot, - %SnapChecker.get_collision_normal())

			var collider: Object = %SnapChecker.get_collider()
			if collider.owner and collider.owner is Entity:
				hook_entity = collider.owner

				sticky_node = Node3D.new()
				sticky_node_normal = Node3D.new()

				collider.add_child(sticky_node)
				tree_exited.connect(sticky_node.queue_free)
				sticky_node.global_position = global_position

				sticky_node.add_child(sticky_node_normal)
				sticky_node_normal.global_position = (sticky_node.global_position - %SnapChecker.get_collision_normal())

				dynamic_hook = true
			else:
				static_hook = true
			hook.call_deferred()
		elif _is_world_position_available(global_position) and Ref.world.is_block_solid_at(global_position):
			static_hook = true
			hook.call_deferred()
		else:
			global_position += velocity * delta


func shoot(initial_direction: Vector3, speed: float, new_hook_owner: Entity) -> void :
	hook_owner = new_hook_owner
	base_speed = speed
	velocity = initial_direction * speed
	_shoot_lifetime = 0.0
	SpatialMath.look_at_local( %RotationPivot, initial_direction)

	%SnapChecker.hit_from_inside = true
	%SnapChecker.position = Vector3(0, 0, 0.05)
	if is_instance_valid(hook_owner):
		%SnapChecker.add_exception(hook_owner.get_node("%InteractArea3D"))


func still_hooked() -> bool:
	%SnapChecker.target_position = Vector3(0, 0.0, -0.5)
	%SnapChecker.force_raycast_update()
	if static_hook:
		return %SnapChecker.is_colliding() or (_is_world_position_available(global_position) and Ref.world.is_block_solid_at(global_position))
	else:
		return is_instance_valid(hook_entity) and not hook_entity.dead


func _is_world_position_available(pos: Vector3) -> bool:
	return is_instance_valid(Ref.world) and Ref.world.is_position_loaded(pos)
