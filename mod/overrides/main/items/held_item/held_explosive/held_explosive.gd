class_name HeldExplosive extends HeldItem

@export var throw_impulse: float = 8.0


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
	super.interact(sustain, data)

	if not _is_world_position_safe(holder.hand.global_position):
		return false

	var new_explosive: PhysicalExplosive = item.physical_explosive.instantiate()
	new_explosive.entity_owner = holder
	get_tree().get_root().add_child(new_explosive)
	new_explosive.freeze = true
	new_explosive.global_position = holder.hand.global_position
	new_explosive.freeze = false

	new_explosive.linear_velocity = holder.velocity + holder.get_look_direction() * throw_impulse
	new_explosive.ignite()

	inventory.change_amount(inventory_index, -1)

	if holder == Ref.player:
		Steamworks.set_achievement("BOMB")

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
