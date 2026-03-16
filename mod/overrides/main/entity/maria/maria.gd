class_name Maria extends Entity

func _ready() -> void :
    rotation_pivot.rotation.y = randf_range(0, 2 * PI)

func _physics_process(_delta: float) -> void :
    if disabled:
        return
    if Ref.coop_manager != null and Ref.coop_manager.has_connected_remote_peers():
        if Ref.coop_manager.get_nearest_session_player_distance(global_position, global_position.distance_to(Ref.player.global_position)) < 17.0:
            queue_free()
        return
    if global_position.distance_to(Ref.player.global_position) < 17.0:
        queue_free()
