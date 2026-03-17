class_name HeldRodThrower extends HeldItem

@export var bolt_scene: PackedScene = preload("res://main/entity/baal/bolt/bolt.tscn")


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
    super.interact(sustain, data)

    if not %CooldownTimer.is_stopped():
        return false

    if not Ref.world.is_position_loaded(holder.hand.global_position) or Ref.world.is_block_solid_at(holder.hand.global_position):
        return false

    if Ref.coop_manager != null and holder == Ref.player and Ref.coop_manager.has_active_session() and Ref.coop_manager.is_client_session():
        if not Ref.coop_manager.sync_local_bolt_throw(holder.hand.global_position, holder.get_look_direction()):
            return false
        holder.decrease_held_item_durability(1)

        var local_player: AudioStreamPlayer3D = %ShootPlayer.duplicate()
        local_player.finished.connect(local_player.queue_free)
        get_tree().get_root().add_child(local_player)
        local_player.global_position = holder.hand.global_position
        local_player.play()

        %CooldownTimer.start()
        return true

    var new_bolt: Bolt = bolt_scene.instantiate()
    get_tree().get_root().add_child(new_bolt)
    new_bolt.global_position = holder.hand.global_position
    new_bolt.entity_owner = holder

    if is_instance_valid(holder) and holder.get_class() == "Manikin":
        print("[lucid-blocks-coop][manikin-debug] fire-rod holder=", holder.name, " look_dir=", holder.get_look_direction(), " hand=", holder.hand.global_position)
    new_bolt.fire(holder.get_look_direction(), true)
    _sync_visual_bolt(new_bolt)
    holder.decrease_held_item_durability(1)

    var new_player: AudioStreamPlayer3D = %ShootPlayer.duplicate()
    new_player.finished.connect(new_player.queue_free)
    get_tree().get_root().add_child(new_player)
    new_player.global_position = holder.hand.global_position
    new_player.play()

    %CooldownTimer.start()

    return true


func _sync_visual_bolt(new_bolt: Bolt) -> void:
    if Ref.coop_manager == null:
        return
    if not Ref.coop_manager.has_active_session():
        return
    if multiplayer.is_server():
        if Ref.coop_manager.is_remote_player_proxy(holder):
            return
        if Ref.coop_manager.has_method("broadcast_host_visual_bolt"):
            Ref.coop_manager.call("broadcast_host_visual_bolt", new_bolt.global_position, holder.get_look_direction())
        return
    if holder == Ref.player and Ref.coop_manager.has_method("send_guest_visual_bolt"):
        Ref.coop_manager.call("send_guest_visual_bolt", new_bolt.global_position, holder.get_look_direction())


func can_interact(_data: Dictionary) -> bool:
    return Ref.world.is_position_loaded(holder.hand.global_position) and not Ref.world.is_block_solid_at(holder.hand.global_position)
