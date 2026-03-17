class_name HeldRodThrower extends HeldItem

@export var bolt_scene: PackedScene = preload("res://main/entity/baal/bolt/bolt.tscn")


func interact(sustain: bool = false, data: Dictionary = {}) -> bool:
    super.interact(sustain, data)

    if not %CooldownTimer.is_stopped():
        return false

    if not Ref.world.is_position_loaded(holder.hand.global_position) or Ref.world.is_block_solid_at(holder.hand.global_position):
        return false

    var new_bolt: Bolt = bolt_scene.instantiate()
    get_tree().get_root().add_child(new_bolt)
    new_bolt.global_position = holder.hand.global_position
    new_bolt.entity_owner = holder

    new_bolt.fire(holder.get_look_direction(), true)
    _broadcast_host_visual_bolt(new_bolt)
    holder.decrease_held_item_durability(1)

    var new_player: AudioStreamPlayer3D = %ShootPlayer.duplicate()
    new_player.finished.connect(new_player.queue_free)
    get_tree().get_root().add_child(new_player)
    new_player.global_position = holder.hand.global_position
    new_player.play()

    %CooldownTimer.start()

    return true


func _broadcast_host_visual_bolt(new_bolt: Bolt) -> void:
    if Ref.coop_manager == null:
        return
    if not multiplayer.is_server() or not Ref.coop_manager.has_active_session():
        return
    if Ref.coop_manager.is_remote_player_proxy(holder):
        return
    if not Ref.coop_manager.has_method("broadcast_host_visual_bolt"):
        return

    Ref.coop_manager.call("broadcast_host_visual_bolt", new_bolt.global_position, holder.get_look_direction())


func can_interact(_data: Dictionary) -> bool:
    return Ref.world.is_position_loaded(holder.hand.global_position) and not Ref.world.is_block_solid_at(holder.hand.global_position)
