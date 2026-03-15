class_name HeldBlaster extends HeldItem

@export var blast_scene: PackedScene


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
	super.interact(sustain, data)
	var blast: Blast = blast_scene.instantiate()
	blast.position = holder.hand.global_position
	get_tree().get_root().add_child(blast)
	blast.shoot(holder.velocity, holder.get_look_direction())
	holder.decrease_held_item_durability(1)
	var new_player: AudioStreamPlayer3D = %BurstPlayer.duplicate()
	new_player.finished.connect(new_player.queue_free)
	get_tree().get_root().add_child(new_player)
	new_player.global_position = holder.hand.global_position
	new_player.play()
	return true


func can_interact(_data: Dictionary) -> bool:
	return true
