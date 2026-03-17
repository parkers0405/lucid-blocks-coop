class_name HeldBlock extends HeldItem

var entity_first_place_position: Vector3
var entity_place_position: Vector3
var placement_check: ShapeCast3D
var place_id: int

var linear_direction: Vector3i
var place_direction: Vector3i
var place_position: Vector3i
var linear_locked: bool = false


func _on_tree_exiting():
    super._on_tree_exiting()
    if is_instance_valid(placement_check):
        placement_check.queue_free()


func _on_alpha_changed(val: float) -> void :
    %Cube.set_instance_shader_parameter("fade", val)


func initialize(set_inventory: Inventory, set_index: int, set_holder: Entity) -> void :
    super.initialize(set_inventory, set_index, set_holder)

    %Cube.visible = not item.foliage and not item.override_icon
    %Cube.set_instance_shader_parameter("index", item.get_index())

    placement_check = %PlacementCheckShapeCast3D
    remove_child(placement_check)
    get_tree().get_root().add_child(placement_check)
    placement_check.scale = Vector3(1, 1, 1)


func _process(_delta: float) -> void :
    if not linear_locked:
        return

    if place_direction == Vector3i():
        if entity_first_place_position.distance_to(holder.global_position) < 0.75:
            return
        place_direction = Vector3i(SpatialMath.snap_to_cardinal(holder.global_position - entity_first_place_position))
    var displacement: Vector3 = (holder.global_position - entity_place_position) * Vector3(place_direction)

    var place_origin: Vector3 = holder.get_node("%InteractRayCast3D").global_position if holder.has_node("%InteractRayCast3D") else holder.hand.global_position
    var place_length: float = holder.get_node("%InteractRayCast3D").target_position.length() if holder.has_node("%InteractRayCast3D") else 5.0

    if can_place() and displacement.max(Vector3()).length() > 0.5 and (place_origin.distance_to(Vector3(place_position) + Vector3(0.5, 0.5, 0.5)) < place_length + 1.0):
        place_block()
        instant_interact_impulse.emit()
        entity_place_position += Vector3(place_direction)


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
    super.interact(sustain, data)

    if not linear_locked:
        place_block()

    linear_locked = true

    return true


func interact_end() -> void :
    super.interact_end()
    linear_locked = false


func _should_sync_coop_place() -> bool:
    if Ref.coop_manager == null:
        return false
    if holder == Ref.player:
        return true
    return multiplayer.is_server() and not Ref.coop_manager.is_remote_player_proxy(holder)


func place_block() -> void :
    var to_place: Item = ItemMap.map(place_id)
    var final_place_position: Vector3i = place_position + place_direction

    if _should_sync_coop_place() and Ref.coop_manager.sync_local_block_place(final_place_position, place_id, inventory, inventory_index):
        place_position = final_place_position
    else:
        place_position = final_place_position
        inventory.change_amount(inventory_index, -1)
        Ref.world.place_block_at(place_position, to_place, true, true)

    if holder == Ref.player:
        Steamworks.increment_statistic("blocks_placed")

    if to_place.internal_name == "plant" or to_place.internal_name == "style_plant":
        Steamworks.set_achievement("PLANT_SEED")


func can_place() -> bool:
    var future_place_position: Vector3i = Vector3(place_position) + Vector3(place_direction)

    placement_check.global_rotation = Vector3()
    placement_check.global_position = Vector3(future_place_position) + Vector3(0.5, 0.5, 0.5)
    placement_check.force_shapecast_update()

    if not Ref.world.is_position_loaded(future_place_position) or Ref.world.is_block_solid_at(future_place_position) or (not item.foliage and placement_check.is_colliding()):
        return false

    if (not item is LetterBlock and item.foliage) and Ref.world.get_block_type_at(future_place_position).id != 0:
        return false
    if (not item is LetterBlock and item.foliage) and (not Ref.world.is_position_loaded(future_place_position - Vector3i(0, 1, 0)) or not Ref.world.is_block_solid_at(future_place_position - Vector3i(0, 1, 0))):
        return false
    if Ref.world.get_living_block_at(future_place_position) != null:
        return false

    return true


func can_interact(data: Dictionary) -> bool:
    if not "target_position_adjacent" in data:
        return false
    if linear_locked:
        return false

    place_position = Vector3i(data.target_position_adjacent.floor())
    place_direction = Vector3i()

    entity_place_position = holder.global_position
    entity_first_place_position = entity_place_position

    placement_check.global_rotation = Vector3()
    placement_check.global_position = Vector3(place_position) + Vector3(0.5, 0.5, 0.5)
    placement_check.force_shapecast_update()

    place_id = item.id
    if (item as Block).directional:
        match Vector3i(data.interact_normal):
            Vector3i(0, 1, 0):
                place_id += 1
            Vector3i(0, -1, 0):
                place_id += 2
            Vector3i(0, 0, 1):
                place_id += 3
            Vector3i(0, 0, -1):
                place_id += 4
            Vector3i(1, 0, 0):
                place_id += 5
            Vector3i(-1, 0, 0):
                place_id += 6
    return can_place()
