class_name HeldCompass extends HeldItem

var nearest_cutscene_block: Vector3i


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
	super.interact(sustain, data)
	var tiamana_trail: TiamanaTrail = holder.get_node("%TiamanaTrail")
	var new_item_state: ItemState = item_state.duplicate()
	new_item_state.id = item.locked_variant_id
	var invalid_blocks: Dictionary[Vector3i, bool] = Ref.plot_manager.collected_cutscene_blocks.merged(Ref.plot_manager.tracked_cutscene_blocks)

	if not is_instance_valid(Ref.world):
		return false

	# Wait for world to load with a timeout so we don't hang forever
	var wait_frames: int = 0
	while not Ref.world.is_all_loaded() and wait_frames < 120:
		await get_tree().process_frame
		wait_frames += 1

	print_rich("[color=#0000ff]Starting compass search.")
	new_item_state.position = Ref.world.find_closest_cutscene_block(global_position, invalid_blocks)
	print_rich("[color=#00ff00]Search completed. Compass pointer: ", new_item_state.position)
	nearest_cutscene_block = new_item_state.position
	Ref.plot_manager.mark_block_as_tracked(nearest_cutscene_block)
	inventory.set_item(inventory_index, new_item_state)
	tiamana_trail.update_state(true, nearest_cutscene_block)
	play_sounds()
	return true


func on_unhold() -> void :
	super.on_unhold()
	if not holder.has_node("%TiamanaTrail"):
		return
	var tiamana_trail: TiamanaTrail = holder.get_node("%TiamanaTrail")
	tiamana_trail.update_state(false, nearest_cutscene_block)


func on_hold() -> void :
	super.on_hold()
	if not is_instance_valid(Ref.world):
		return
	if Ref.main.creative or Ref.world.current_dimension != LucidBlocksWorld.Dimension.NARAKA:
		return
	if not holder.has_node("%TiamanaTrail"):
		return
	var tiamana_trail: TiamanaTrail = holder.get_node("%TiamanaTrail")
	if item.is_locked:
		nearest_cutscene_block = item_state.position
		if not Ref.plot_manager.is_block_collected(nearest_cutscene_block):
			tiamana_trail.update_state(true, nearest_cutscene_block)


func can_interact(_data: Dictionary) -> bool:
	if not is_instance_valid(Ref.world):
		return false
	return Ref.world.current_dimension == LucidBlocksWorld.Dimension.NARAKA and not Ref.main.creative and holder.has_node("%TiamanaTrail") and Ref.world.is_position_loaded(global_position) and not item.is_locked


func play_sounds() -> void :
	var new_player: AudioStreamPlayer3D = %JinglePlayer.duplicate()
	new_player.finished.connect(new_player.queue_free)
	get_tree().get_root().add_child(new_player)
	new_player.global_position = global_position
	new_player.play()
	var new_player_2: AudioStreamPlayer = ( %OffPlayer.duplicate() if holder.get_node("%TiamanaTrail").active else %OnPlayer.duplicate())
	new_player_2.finished.connect(new_player_2.queue_free)
	get_tree().get_root().add_child(new_player_2)
	new_player_2.play()
