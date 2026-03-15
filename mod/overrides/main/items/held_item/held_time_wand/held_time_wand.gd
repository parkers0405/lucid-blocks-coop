class_name HeldTimeWand extends HeldItem

func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
	super.interact(sustain, data)
	Steamworks.set_achievement("HAND_WAND")

	# Time changes should be host-authoritative
	if Ref.coop_manager != null and Ref.coop_manager.has_active_session() and not multiplayer.is_server():
		# Guest sends time change request to host (not implemented yet, just skip)
		return false

	if is_equal_approx(Ref.sun.target_time_scale, 1.0):
		Ref.sun.set_time_scale(0.5)
	else:
		Ref.sun.set_time_scale(1.0)
	holder.decrease_held_item_durability(1)
	var new_player: AudioStreamPlayer = %TimePlayer.duplicate()
	new_player.finished.connect(new_player.queue_free)
	get_tree().get_root().add_child(new_player)
	new_player.play()
	return true

func can_interact(_data: Dictionary) -> bool:
	return true
