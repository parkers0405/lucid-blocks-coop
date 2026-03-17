class_name Baal extends Entity

@export var bolt_scene: PackedScene


func _ready() -> void :
    super._ready()

    remove_from_group("preserve_but_delete_on_unload")
    add_to_group("preserve")

    position.y += 16
    %ShootTimer.timeout.connect(_on_shoot_timeout)
    movement_velocity = speed * Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()

    modulate_changed.connect(_on_modulate_changed)
    alpha_changed.connect(_on_alpha_changed)


func _on_modulate_changed(new_modulate: Color) -> void :
    %Core.set("instance_shader_parameters/albedo", new_modulate)


func _on_alpha_changed(new_alpha: float) -> void :
    %Core.set("instance_shader_parameters/fade", new_alpha)


func _on_shoot_timeout() -> void :
    if disabled or dead:
        return

    var new_bolt: Bolt = bolt_scene.instantiate()
    new_bolt.entity_owner = self
    get_tree().get_root().add_child(new_bolt)
    new_bolt.global_position = global_position
    var shoot_direction: Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
    if new_bolt.fire(shoot_direction):
        %ElecPlayer.play()


func _physics_process(delta: float) -> void :
    if disabled or not is_session_position_loaded(global_position):
        return
    distance_process_check()

    velocity = movement_velocity
    if is_future_position_loaded(delta):
        global_position += velocity * delta
