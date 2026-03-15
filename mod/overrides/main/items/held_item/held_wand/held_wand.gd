class_name HeldWand extends HeldItem


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
	super.interact(sustain, data)
	if holder.has_node("%Curse"):
		var curse: Curse = holder.get_node("%Curse")
		var new_player: AudioStreamPlayer3D = ( %ScreechPlayer if not curse.is_cursed else %UnscreechPlayer).duplicate()
		new_player.finished.connect(new_player.queue_free)
		get_tree().get_root().add_child(new_player)
		new_player.global_position = global_position
		new_player.play()
		if curse.is_cursed:
			curse.uncurse()
		else:
			curse.curse()
		holder.decrease_held_item_durability(1)
		Steamworks.set_achievement("FAITH_WAND")
		return true
	return false


func can_interact(_data: Dictionary) -> bool:
	return true
