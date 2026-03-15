class_name HeldRope extends HeldItem

@export var max_distance: float = 32.0
@export var full_strength_distance: float = 6
@export var shoot_speed: float = 32
@export var pull_speed: float = 16
@export var vertical_pull_speed: float = 24
@export var first_jump_pulse: float = 4.0
@export var hook_scene: PackedScene

var hooked: bool = false
var retracting: bool = false
var pulling: bool = false
var hook: Hook
var reel: AudioStreamPlayer3D


func _ready() -> void :
	super._ready()
	set_physics_process(false)
	if is_instance_valid(Ref.world):
		Ref.world.block_broken.connect(_on_block_broken)


func _on_tree_exiting() -> void :
	abandon(true)


func _on_hooked() -> void :
	hooked = true
	holder.decrease_held_item_durability(1)
	start_pulling()


func _on_block_broken(_break_position: Vector3i) -> void :
	check_hook.call_deferred()


func check_hook() -> void :
	if is_instance_valid(hook) and not hook.still_hooked() and not pulling:
		abandon(false)


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
	super.interact(sustain, data)
	if not sustain:
		return false
	# Guard: don't shoot if world isn't loaded here
	if not is_instance_valid(Ref.world) or not Ref.world.is_position_loaded(global_position):
		return false

	if retracting or pulling:
		abandon(true)

	holding_interact = sustain

	reel = %Reel.duplicate()
	get_tree().get_root().add_child(reel)
	reel.play()

	shoot_hook()

	if holder == Ref.player:
		Steamworks.set_achievement("HOOKSHOT")

	return true


func interact_end() -> void :
	holding_interact = false
	abandon(false)


func start_pulling() -> void :
	set_physics_process(true)


func delete_hook() -> void :
	if not is_instance_valid(hook):
		return
	if is_instance_valid(hook.hook_entity):
		hook.hook_entity.rope_velocities.erase(self)
	hook.queue_free()


func retract_hook() -> void :
	if not is_instance_valid(hook):
		return
	retracting = true
	hook.retracting = true
	await hook.retracted
	if retracting:
		stop_hook()


func abandon(immediate: bool) -> void :
	if is_instance_valid(holder) and self in holder.rope_velocities:
		holder.residual_rope_velocity += holder.rope_velocities[self]
		holder.rope_velocities.erase(self)

	set_physics_process(false)
	if immediate:
		stop_hook()
	else:
		retract_hook()


func shoot_hook() -> void :
	if pulling:
		return
	retracting = false
	pulling = true
	holding_animation = true

	delete_hook()

	hook = hook_scene.instantiate()
	get_tree().get_root().add_child(hook)
	hook.hooked.connect(_on_hooked)
	hook.global_position = global_position
	hook.shoot(holder.get_look_direction(), shoot_speed, holder)


func stop_hook() -> void :
	holding_animation = false
	pulling = false
	retracting = false
	hooked = false

	delete_hook()

	if is_instance_valid(reel):
		var tween: Tween = get_tree().create_tween()
		tween.tween_property(reel, "volume_db", -80, 1.0)
		tween.finished.connect(reel.queue_free)


func rope_process(delta: float, subject: Entity, subject_root: Vector3, target_root: Vector3, multiplier: float = 1.0) -> float:
	var displacement_vector: Vector3 = target_root - subject_root
	var distance: float = displacement_vector.length()
	displacement_vector = displacement_vector.normalized()
	var strength: float = multiplier * clamp(distance / full_strength_distance, 0.0, 4.0)

	var gravity: float = delta * displacement_vector.y * vertical_pull_speed * strength
	if displacement_vector.y > 0:
		gravity *= 2
	subject.gravity_velocity += Vector3(0, gravity, 0)

	var subject_rope_velocity: Vector3 = displacement_vector * pull_speed * strength

	if subject.is_on_floor() and is_instance_valid(hook) and not hook.global_position.y - full_strength_distance < holder.global_position.y:
		subject_rope_velocity.y = first_jump_pulse * clamp(strength, 0.0, 1.0)
	if subject.is_on_ceiling() and holder.rope_velocities[self].y < 0:
		subject.gravity_velocity.y = 0

	subject.rope_velocities[self] = subject_rope_velocity

	return distance


func _physics_process(delta: float) -> void :
	if not is_instance_valid(holder):
		return
	if not is_instance_valid(hook):
		return

	holder.rope_velocities[self] = Vector3()

	var distance: float = 0.0
	if hook.dynamic_hook and is_instance_valid(hook.hook_entity) and not hook.hook_entity.dead:
		hook.hook_entity.rope_velocities[self] = Vector3()
		distance = rope_process(delta, holder, holder.hand.global_position, hook.global_position, clamp(hook.hook_entity.weight / holder.weight, 0.0, 1.0))
		rope_process(delta, hook.hook_entity, hook.global_position, holder.hand.global_position, clamp(holder.weight / hook.hook_entity.weight, 0.0, 1.0))
	else:
		distance = rope_process(delta, holder, holder.hand.global_position, hook.global_position)
	reel.pitch_scale = lerp(reel.pitch_scale, clamp(distance / 16.0, 0.5, 1.2), delta * 8.0)
	reel.volume_db = lerp(reel.volume_db, -34 - 8 + 4 * clamp(distance / 6.0, 0.0, 1.0), delta * 4.0)

	if is_instance_valid(reel):
		reel.global_position = holder.hand.global_position


func _process(_delta: float) -> void :
	if is_instance_valid(reel):
		reel.global_position = holder.hand.global_position

	if not is_instance_valid(hook):
		%Rope.visible = false
	else:
		var hook_tip: Vector3 = hook.get_node("%Model").global_position

		%Rope.visible = true
		%Rope.scale.x = (hook_tip - holder.hand.global_position).length()
		%RopeRotationPivot.global_position = holder.hand.global_position

		SpatialMath.look_at( %RopeRotationPivot, hook_tip)

		if holder.hand.global_position.distance_to(hook.global_position) > max_distance:
			retract_hook()

		if not (hook.shooting or hook.retracting) and not hook.still_hooked():
			stop_hook()


func can_interact(_data: Dictionary) -> bool:
	return true
