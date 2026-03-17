class_name HeldIgniter extends HeldItem


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
    super.interact(sustain, data)

    if "target" in data:
        if not data.target.has_node("%Burn"):
            return false

        if Ref.coop_manager != null and Ref.coop_manager.is_client_session() and not Ref.coop_manager.is_remote_player_proxy(data.target):
            return true

        data.target.get_node("%Burn").ignite()

        var new_player: AudioStreamPlayer3D = %StrikePlayer.duplicate()
        get_tree().get_root().add_child(new_player)
        new_player.global_position = data.target.get_node("%Burn").global_position
        new_player.play()
        inventory.change_amount(inventory_index, -1)

        return true

    if "target_position" in data:
        if not Ref.world.is_position_loaded(data.target_position):
            return false

        Ref.world.place_fire_at(data.target_position, 1)
        if Ref.world.get_fire_at(data.target_position) <= 0:
            return false

        var strike_player: AudioStreamPlayer3D = %StrikePlayer.duplicate()
        strike_player.finished.connect(strike_player.queue_free)
        get_tree().get_root().add_child(strike_player)
        strike_player.global_position = data.target_position
        strike_player.play()
        inventory.change_amount(inventory_index, -1)

        if Ref.coop_manager != null:
            Ref.coop_manager.sync_local_fire_cell(Vector3i(data.target_position), 1)
        return true

    return false


func can_interact(data: Dictionary) -> bool:
    if not ("target" in data or "target_position" in data):
        return false

    if "target" in data:
        return data.target.has_node("%Burn")
    if "target_position" in data:
        return Ref.world.is_position_loaded(data.target_position) and Ref.world.fire_eligible(data.target_position)
    return false
