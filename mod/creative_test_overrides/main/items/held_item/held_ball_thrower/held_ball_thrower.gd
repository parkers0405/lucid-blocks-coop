class_name HeldBallThrower extends HeldItem

@export var throw_impulse: float = 18.0
@export var ball_scene: PackedScene = preload("res://main/items/held_item/held_ball_thrower/ball.tscn")


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
    super.interact(sustain, data)

    if not %CooldownTimer.is_stopped():
        return false

    if not Ref.world.is_position_loaded(holder.hand.global_position) or Ref.world.is_block_solid_at(holder.hand.global_position):
        return false

    var new_ball: Ball = ball_scene.instantiate()
    new_ball.entity_owner = holder
    get_tree().get_root().add_child(new_ball)
    new_ball.global_position = holder.hand.global_position

    new_ball.linear_velocity = holder.velocity + holder.get_look_direction() * throw_impulse
    _broadcast_host_visual_ball_throw(new_ball)

    holder.decrease_held_item_durability(1)

    var new_player: AudioStreamPlayer3D = %ShootPlayer.duplicate()
    new_player.finished.connect(new_player.queue_free)
    get_tree().get_root().add_child(new_player)
    new_player.global_position = holder.hand.global_position
    new_player.play()

    %CooldownTimer.start()

    if holder == Ref.player:
        Steamworks.set_achievement("BALL_WAND")

    return true


func _broadcast_host_visual_ball_throw(new_ball: Ball) -> void:
    if Ref.coop_manager == null:
        return
    if not multiplayer.is_server() or not Ref.coop_manager.has_active_session():
        return
    if Ref.coop_manager.is_remote_player_proxy(holder):
        return
    if not Ref.coop_manager.has_method("broadcast_host_visual_ball_throw"):
        return

    Ref.coop_manager.call("broadcast_host_visual_ball_throw", new_ball.global_position, new_ball.linear_velocity)


func can_interact(_data: Dictionary) -> bool:
    return Ref.world.is_position_loaded(holder.hand.global_position) and not Ref.world.is_block_solid_at(holder.hand.global_position)
