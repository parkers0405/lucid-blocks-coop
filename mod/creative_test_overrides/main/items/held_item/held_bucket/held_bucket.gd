class_name HeldBucket extends HeldItem

var cached_potential_cells: Array[Vector3]


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
    super.interact(sustain, data)

    for place_position in cached_potential_cells:
        place_position = place_position.floor()
        if not Ref.world.is_position_loaded(place_position):
            continue
        if Ref.world.is_block_solid_at(place_position):
            continue

        var water: int = Ref.world.get_water_level_at(place_position)
        var applied_changes: Array = []

        if not item is BucketTool or item.filled:
            if water >= 255:
                continue
            var original_water: int = Ref.world.get_water_level_at(place_position)
            var remaining_water: int = original_water

            Ref.world.place_water_at(place_position, 255)
            applied_changes.append([Vector3i(place_position), 255])

            if remaining_water > 0:
                var directions_to_check: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]
                directions_to_check.shuffle()

                for dir in directions_to_check:
                    if not Ref.world.is_position_loaded(place_position + dir) or Ref.world.is_block_solid_at(place_position + dir):
                        continue
                    var adj_original_water: int = Ref.world.get_water_level_at(place_position + dir)
                    var new_level: int = clamp(adj_original_water + remaining_water, 0, 255)
                    Ref.world.place_water_at(place_position + dir, new_level)
                    applied_changes.append([Vector3i(place_position + dir), new_level])
                    remaining_water -= adj_original_water
                    if remaining_water < 0:
                        break

            var new_player: AudioStreamPlayer3D = %SpillPlayer.duplicate()
            new_player.finished.connect(new_player.queue_free)
            get_tree().get_root().add_child(new_player)
            new_player.global_position = place_position
            new_player.play()
        else:
            if water <= 128:
                continue
            Ref.world.place_water_at(place_position, 0)
            applied_changes.append([Vector3i(place_position), 0])

            var new_player: AudioStreamPlayer3D = %FillPlayer.duplicate()
            new_player.finished.connect(new_player.queue_free)
            get_tree().get_root().add_child(new_player)
            new_player.global_position = place_position
            new_player.play()

        var new_player2: AudioStreamPlayer3D = %SplashPlayer.duplicate()
        new_player2.finished.connect(new_player2.queue_free)
        get_tree().get_root().add_child(new_player2)
        new_player2.global_position = place_position
        new_player2.play()

        if not item is BucketTool:
            inventory.change_amount(inventory_index, -1)
        elif item.opposite_variant_id != item.id:
            var new_item_state: ItemState = item_state.duplicate()
            new_item_state.id = item.opposite_variant_id
            inventory.set_item(inventory_index, new_item_state)

        if Ref.coop_manager != null:
            Ref.coop_manager.sync_local_water_cells(applied_changes)
        return true
    return false


func can_interact(data: Dictionary) -> bool:
    if not ("interact_begin" in data and "interact_end" in data and not ((not item is BucketTool or item.filled) and not "target_position" in data)):
        return false

    cached_potential_cells = BlockMath.visit_all(data.interact_begin, data.interact_end)
    if not item is BucketTool or item.filled:
        cached_potential_cells.reverse()

    for place_position in cached_potential_cells:
        place_position = place_position.floor()
        if not Ref.world.is_position_loaded(place_position) or Ref.world.is_block_solid_at(place_position):
            continue

        var water: int = Ref.world.get_water_level_at(place_position)
        if (not item is BucketTool or item.filled) and water < 255 or (item is BucketTool and not item.filled and water > 128):
            return true
    return false
