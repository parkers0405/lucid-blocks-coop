class_name HeldHeartThrower extends HeldItem

@export var throw_impulse: float = 18.0
@export var heart_scene: PackedScene


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
	super.interact(sustain, data)
	if not %CooldownTimer.is_stopped():
		return false
	if not _is_world_position_safe(holder.hand.global_position):
		return false
	var new_heart: Heart = heart_scene.instantiate()
	new_heart.entity_owner = holder
	get_tree().get_root().add_child(new_heart)
	new_heart.global_position = holder.hand.global_position
	new_heart.linear_velocity = holder.velocity + holder.get_look_direction() * throw_impulse
	holder.decrease_held_item_durability(1)
	var new_player: AudioStreamPlayer3D = %ShootPlayer.duplicate()
	new_player.finished.connect(new_player.queue_free)
	get_tree().get_root().add_child(new_player)
	new_player.global_position = holder.hand.global_position
	new_player.play()
	if holder == Ref.player:
		Steamworks.set_achievement("BALL_WAND")
	return true


func can_interact(_data: Dictionary) -> bool:
	return true


func _is_world_position_safe(pos: Vector3) -> bool:
	if not is_instance_valid(Ref.world):
		return false
	if not Ref.world.is_position_loaded(pos):
		return false
	if Ref.world.is_block_solid_at(pos):
		return false
	return true
