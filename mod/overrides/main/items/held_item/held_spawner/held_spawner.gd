class_name HeldSpawner extends HeldItem

@export var throw_impulse: float = 18.0


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
    super.interact(sustain, data)

    if not Ref.world.is_position_loaded(holder.hand.global_position) or Ref.world.is_block_solid_at(holder.hand.global_position):
        return false

    var throw_velocity: Vector3 = holder.velocity + holder.get_look_direction() * throw_impulse
    if Ref.coop_manager != null and Ref.coop_manager.sync_local_capsule_throw(item.id, holder.hand.global_position, throw_velocity):
        _play_throw_audio(holder.hand.global_position)
        inventory.change_amount(inventory_index, -1)
        return true

    if item.entity_scene == null:
        item.entity_scene = ResourceLoader.load(item.entity_path)

    var new_capsule: SpawnProjectile = item.projectile_scene.instantiate()
    get_tree().get_root().add_child(new_capsule)
    new_capsule.global_position = holder.hand.global_position
    new_capsule.initialize(throw_velocity, item, item.entity_scene)

    _play_throw_audio(holder.hand.global_position)
    inventory.change_amount(inventory_index, -1)
    return true


func _play_throw_audio(play_position: Vector3) -> void:
    var new_pop_player: AudioStreamPlayer3D = %ThrowPlayer.duplicate()
    get_tree().get_root().add_child(new_pop_player)
    new_pop_player.global_position = play_position
    new_pop_player.finished.connect(new_pop_player.queue_free)
    new_pop_player.play()


func can_interact(_data: Dictionary) -> bool:
    return Ref.world.is_position_loaded(holder.hand.global_position) and not Ref.world.is_block_solid_at(holder.hand.global_position)
