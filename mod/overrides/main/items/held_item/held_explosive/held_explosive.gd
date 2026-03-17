class_name HeldExplosive extends HeldItem

@export var throw_impulse: float = 8.0


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
    super.interact(sustain, data)

    if Ref.coop_manager != null and holder == Ref.player and Ref.coop_manager.has_active_session() and Ref.coop_manager.is_client_session():
        var explosive_scene_path: String = ""
        if item != null and item.physical_explosive != null:
            explosive_scene_path = item.physical_explosive.resource_path
        var throw_velocity: Vector3 = holder.velocity + holder.get_look_direction() * throw_impulse
        if not Ref.coop_manager.sync_local_explosive_throw(explosive_scene_path, holder.hand.global_position, throw_velocity):
            return false
        inventory.change_amount(inventory_index, -1)
        Steamworks.set_achievement("BOMB")
        return true

    var new_explosive: PhysicalExplosive = item.physical_explosive.instantiate()
    new_explosive.entity_owner = holder
    get_tree().get_root().add_child(new_explosive)
    new_explosive.freeze = true
    new_explosive.global_position = holder.hand.global_position
    new_explosive.freeze = false

    new_explosive.linear_velocity = holder.velocity + holder.get_look_direction() * throw_impulse
    new_explosive.ignite()

    inventory.change_amount(inventory_index, -1)

    if holder == Ref.player:
        Steamworks.set_achievement("BOMB")

    return true


func can_interact(_data: Dictionary) -> bool:
    if not Ref.world.is_position_loaded(holder.hand.global_position) or Ref.world.is_block_solid_at(holder.hand.global_position):
        return false
    return true
