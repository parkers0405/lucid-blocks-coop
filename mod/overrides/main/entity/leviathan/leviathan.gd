class_name Leviathan extends Entity

@export var music: AudioStream

@export var sky_color: Color = Color.RED
@export var melt_radius: float = 64.0
@export var melt_chance: float = 0.25

static var count: int = 0


func _ready() -> void :
    super._ready()
    remove_from_group("preserve_but_delete_on_unload")
    add_to_group("preserve")
    global_position.y += 32
    if count == 0:
        Ref.audio_manager.play_song(music, 5)
        Ref.weather.weather_override = "acid rain"
        Ref.sky.add_sky_tint_override(sky_color)
        Ref.sun.visible = false
    tree_exiting.connect(_on_tree_exiting)
    count += 1
    modulate_changed.connect(_on_modulate_changed)
    alpha_changed.connect(_on_alpha_changed)

    Ref.save_file_manager.settings_updated.connect(_on_settings_updated)
    _on_settings_updated()


func _on_settings_updated() -> void :
    var shadow_quality: int = Ref.save_file_manager.settings_file.get_data("shadow_quality", 2)

    match shadow_quality:
        0:
            %RedSunLight.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
        1:
            %RedSunLight.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
        2:
            %RedSunLight.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


func _on_modulate_changed(new_modulate: Color) -> void :
    %Hand.set("instance_shader_parameters/albedo", new_modulate)


func _on_alpha_changed(new_alpha: float) -> void :
    %Hand.set("instance_shader_parameters/fade", new_alpha)


func _on_tree_exiting() -> void :
    count -= 1
    if count == 0:
        Ref.audio_manager.stop_song(music)
        Ref.weather.weather_override = ""
        Ref.sky.remove_sky_tint_override()
        Ref.sun.visible = true


func get_melt_position() -> Vector3:
    var melt_position: Vector3 = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
    melt_position = melt_position.normalized() * randf_range(0.1, 1) * melt_radius
    melt_position.y = 64
    melt_position += global_position
    return melt_position


func attempt_melt() -> void :
    %MeltRayCast3D.global_position = get_melt_position()
    %MeltRayCast3D.force_raycast_update()
    if %MeltRayCast3D.is_colliding():
        var melt_position: Vector3 = %MeltRayCast3D.get_collision_point() - Vector3(0, 0.5, 0)
        var above_position: Vector3 = melt_position + Vector3(0, 1, 0)
        if Ref.world.is_position_loaded(melt_position) and Ref.world.is_position_loaded(above_position) and not Ref.world.is_under_water(above_position):
            var block_type: Block = Ref.world.get_block_type_at(melt_position)
            if not block_type.griefable:
                return
            Ref.world.break_block_at(melt_position, false, false)
            var new_player: AudioStreamPlayer3D = %SizzlePlayer.duplicate()
            get_tree().get_root().add_child(new_player)
            new_player.global_position = melt_position
            new_player.play()
            new_player.finished.connect(new_player.queue_free)


func _physics_process(_delta: float) -> void :
    if disabled or dead:
        return
    distance_process_check()
    if randf() < melt_chance:
        attempt_melt()


func _process(_delta: float) -> void :
    %RedSun.global_position = get_session_target_position(Ref.player.global_position) + Vector3(0, 80, 0)
