class_name HeldRodThrower extends HeldItem

@export var bolt_scene: PackedScene = preload("res://main/entity/baal/bolt/bolt.tscn")


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
	super.interact(sustain, data)

	if not %CooldownTimer.is_stopped():
		return false

	if not _is_world_position_safe(holder.hand.global_position):
		return false

	var new_bolt: Bolt = bolt_scene.instantiate()
	get_tree().get_root().add_child(new_bolt)
	new_bolt.global_position = holder.hand.global_position
	new_bolt.entity_owner = holder

	new_bolt.fire(holder.get_look_direction(), true)
	holder.decrease_held_item_durability(1)

	var new_player: AudioStreamPlayer3D = %ShootPlayer.duplicate()
	new_player.finished.connect(new_player.queue_free)
	get_tree().get_root().add_child(new_player)
	new_player.global_position = holder.hand.global_position
	new_player.play()

	%CooldownTimer.start()

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
