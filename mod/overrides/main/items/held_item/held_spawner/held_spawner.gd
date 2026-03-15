class_name HeldSpawner extends HeldItem

@export var throw_impulse: float = 18.0


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
	super.interact(sustain, data)
	if not _is_world_position_safe(holder.hand.global_position):
		return false
	if item.entity_scene == null:
		item.entity_scene = ResourceLoader.load(item.entity_path)
	var new_capsule: SpawnProjectile = item.projectile_scene.instantiate()
	get_tree().get_root().add_child(new_capsule)
	new_capsule.global_position = holder.hand.global_position
	new_capsule.initialize(holder.velocity + holder.get_look_direction() * throw_impulse, item, item.entity_scene)
	var new_pop_player: AudioStreamPlayer3D = %ThrowPlayer.duplicate()
	get_tree().get_root().add_child(new_pop_player)
	new_pop_player.global_position = holder.hand.global_position
	new_pop_player.finished.connect(new_pop_player.queue_free)
	new_pop_player.play()
	inventory.change_amount(inventory_index, -1)
	return true


func can_interact(_data: Dictionary) -> bool:
	return _is_world_position_safe(holder.hand.global_position)


func _is_world_position_safe(pos: Vector3) -> bool:
	if not is_instance_valid(Ref.world):
		return false
	if not Ref.world.is_position_loaded(pos):
		return false
	if Ref.world.is_block_solid_at(pos):
		return false
	return true
