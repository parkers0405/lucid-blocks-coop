class_name HeldHeartThrower extends HeldItem

@export var throw_impulse: float = 18.0
@export var heart_scene: PackedScene


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
    super.interact(sustain, data)

    if not %CooldownTimer.is_stopped() or HeldGun.is_switch_fire(Ref.sun.session_cumulative_time, %CooldownTimer.wait_time, item):
        return false

    if not can_interact(data):
        return false

    var new_heart: Heart = heart_scene.instantiate()
    new_heart.entity_owner = holder
    new_heart.position = holder.hand.global_position
    get_tree().get_root().add_child(new_heart)

    new_heart.linear_velocity = holder.velocity + holder.get_look_direction() * throw_impulse
    _sync_visual_heart_throw(new_heart)

    holder.decrease_held_item_durability(1)

    var new_player: AudioStreamPlayer3D = %ShootPlayer.duplicate()
    new_player.finished.connect(new_player.queue_free)
    get_tree().get_root().add_child(new_player)
    new_player.global_position = holder.hand.global_position
    new_player.play()

    %CooldownTimer.start()

    item.last_shot_time = Ref.sun.session_cumulative_time

    return true


func _sync_visual_heart_throw(new_heart: Heart) -> void:
    if Ref.coop_manager == null:
        return
    if not Ref.coop_manager.has_active_session():
        return
    if multiplayer.is_server():
        if Ref.coop_manager.is_remote_player_proxy(holder):
            return
        if Ref.coop_manager.has_method("broadcast_host_visual_heart_throw"):
            Ref.coop_manager.call("broadcast_host_visual_heart_throw", new_heart.global_position, new_heart.linear_velocity)
        return
    if holder == Ref.player and Ref.coop_manager.has_method("send_guest_visual_heart_throw"):
        Ref.coop_manager.call("send_guest_visual_heart_throw", new_heart.global_position, new_heart.linear_velocity)


func can_interact(_data: Dictionary) -> bool:
    return Ref.world.is_position_loaded(holder.hand.global_position) and not Ref.world.is_block_solid_at(holder.hand.global_position)
