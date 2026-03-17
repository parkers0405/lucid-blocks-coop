class_name HeldHoe extends HeldTool

@export var dropped_item_scene: PackedScene = preload("res://main/items/dropped_item/dropped_item.tscn")

var cached_potential_cells: Array[Vector3]


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
    super.interact(sustain, data)

    for place_position in cached_potential_cells:
        place_position = place_position.floor()
        if not Ref.world.is_position_loaded(place_position):
            continue
        if Ref.world.is_block_solid_at(place_position):
            continue

        var block: Block = Ref.world.get_block_type_at(place_position)
        if not block.foliage:
            continue

        var block_position: Vector3i = Vector3i(place_position)

        if Ref.coop_manager != null and holder == Ref.player and Ref.coop_manager.sync_local_foliage_break(block_position):
            holder.decrease_held_item_durability(1)
            return true

        if _should_broadcast_host_foliage_break():
            Ref.coop_manager.request_foliage_break(block_position)
            holder.decrease_held_item_durability(1)
            return true

        Ref.world.break_block_at(place_position, true, false)
        if block.can_drop:
            var new_state: ItemState = ItemState.new()
            new_state.initialize(block)
            new_state.count = 1

            var new_item: DroppedItem = dropped_item_scene.instantiate()
            get_tree().get_root().add_child(new_item)
            new_item.global_position = Vector3(place_position)
            new_item.initialize(new_state)

        holder.decrease_held_item_durability(1)
        return true
    return false


func _should_broadcast_host_foliage_break() -> bool:
    return Ref.coop_manager != null and multiplayer.is_server() and Ref.coop_manager.has_active_session() and not Ref.coop_manager.is_remote_player_proxy(holder)


func can_interact(data: Dictionary) -> bool:
    if not "interact_begin" in data or not "interact_end" in data:
        return false

    cached_potential_cells = BlockMath.visit_all(data.interact_begin, data.interact_end)

    for place_position in cached_potential_cells:
        place_position = place_position.floor()
        if not Ref.world.is_position_loaded(place_position):
            continue
        if Ref.world.is_block_solid_at(place_position):
            continue

        var block: Block = Ref.world.get_block_type_at(place_position)
        if block.foliage:
            return true
    return false
