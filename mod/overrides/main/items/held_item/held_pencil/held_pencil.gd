class_name HeldPencil extends HeldItem


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
	super.interact(sustain, data)
	var target: Entity = data.target
	if not target.can_rename:
		return false
	Ref.game_menu.request_entity_name(target.nickname)
	var request_result: Array = await Ref.game_menu.rename_complete
	var cancelled: bool = request_result[1]
	var new_name: String = request_result[0]
	if cancelled:
		return false
	if is_instance_valid(target):
		target.nickname = new_name
	else:
		return false
	var new_player: AudioStreamPlayer3D = %WritePlayer.duplicate()
	get_tree().get_root().add_child(new_player)
	new_player.global_position = data.target.get_node("%NameTag").global_position
	new_player.play()
	holder.decrease_held_item_durability(1)
	Steamworks.set_achievement("RENAME_ENTITY")
	return true


func can_interact(data: Dictionary) -> bool:
	if not "target" in data:
		return false
	var target: Entity = data.target
	return target.can_rename
