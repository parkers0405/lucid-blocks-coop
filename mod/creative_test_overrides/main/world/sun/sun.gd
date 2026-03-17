class_name Sun extends DirectionalLight3D

@export var wrath_modulate: Color
@export_range(0.1, 120, 0.1, "suffix:min") var day_length: float
@export var time: float = 0.25:
    set(val):
        time_changed.emit(val)
        time = val
@export var brightness_curve: CurveTexture
@export var height_brightness_curve: CurveTexture
@export var light_color_gradient: GradientTexture1D

signal days_elapsed_changed(new_days: int)
signal time_changed(new_time: float)

var days_elapsed: int = 0
var frame: int = 0
var depth_scale: float = 0
var cumulative_time: float = 0.0
var time_moving: bool = true
var time_tween: Tween
var target_time_scale: float = 1.0


func _ready() -> void :
    process_mode = Node.PROCESS_MODE_ALWAYS
    Ref.save_file_manager.settings_updated.connect(_on_settings_updated)
    _on_settings_updated()
    global_rotation.y = 0.01


func _on_settings_updated() -> void :
    var shadow_quality: int = Ref.save_file_manager.settings_file.get_data("shadow_quality", 2)
    match shadow_quality:
        0:
            ProjectSettings.set("rendering/lights_and_shadows/directional_shadow/size", 256)
            ProjectSettings.set("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 0)
            directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
            directional_shadow_max_distance = 30.0
            directional_shadow_blend_splits = false
        1:
            ProjectSettings.set("rendering/lights_and_shadows/directional_shadow/size", 2048)
            ProjectSettings.set("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 1)
            directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
            directional_shadow_max_distance = 40.0
            directional_shadow_blend_splits = true
        2:
            ProjectSettings.set("rendering/lights_and_shadows/directional_shadow/size", 4096)
            ProjectSettings.set("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 2)
            directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
            directional_shadow_max_distance = 60.0
            directional_shadow_blend_splits = true


func _physics_process(_delta: float) -> void :
    frame += 1
    frame = frame % 360
    if frame % 16 == 0:
        var angle := (time * PI * 2.0) - PI * 0.5
        var spin := Quaternion(Vector3.UP, angle)
        var tilt := Quaternion(Vector3.RIGHT, -deg_to_rad(30.0))
        var q := spin * tilt
        rotation = q.get_euler()


func _process(delta: float) -> void :
    var time_scale: float = 1.0 / (60 * day_length)
    if time_moving:
        if time >= 1.0:
            days_elapsed += 1
            days_elapsed_changed.emit(days_elapsed)
            time = 0.0
        time += delta * time_scale
        cumulative_time += delta

    depth_scale = get_height_x()
    light_energy = brightness_curve.curve.sample(time) * height_brightness_curve.curve.sample(depth_scale)
    light_color = light_color_gradient.gradient.sample(time)
    if Ref.main.wrathful_torus:
        light_color *= wrath_modulate
    light_specular = (Ref.sky.sky_base * light_color).get_luminance()


func get_height_x() -> float:
    var focus_y: float = Ref.player.global_position.y
    if is_instance_valid(Ref.player_camera):
        focus_y = Ref.player_camera.global_position.y
    if focus_y < 0:
        return min(-focus_y / 48.0, 1.0)
    return 0.0


func set_time_scale(new_scale: float) -> void :
    if is_instance_valid(time_tween) and time_tween.is_running():
        time_tween.stop()
    target_time_scale = new_scale
    time_tween = get_tree().create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    time_tween.tween_property(Engine, "time_scale", target_time_scale, 0.5)
    time_tween.tween_property(AudioServer, "playback_speed_scale", target_time_scale, 0.5)
    time_tween.tween_property(Ref.environment.environment, "adjustment_saturation", target_time_scale, 0.5)
    await time_tween.finished


func is_day() -> bool:
    return time < 0.225 or time > 0.775


func exit_game() -> void :
    set_time_scale(1.0)


func save_file(file: SaveFile) -> void :
    file.set_data("sun/time", time)
    file.set_data("sun/cumulative_time", cumulative_time)
    file.set_data("sun/days_elapsed", days_elapsed)
    file.set_data("sun/time_scale", target_time_scale)


func load_file(file: SaveFile) -> void :
    time = file.get_data("sun/time", 0.8)
    cumulative_time = file.get_data("sun/cumulative_time", 0.0)
    days_elapsed = file.get_data("sun/days_elapsed", 0)
    target_time_scale = file.get_data("sun/time_scale", 1.0)
    set_time_scale(target_time_scale)
    if Ref.world.current_dimension == LucidBlocksWorld.Dimension.CHALLENGE:
        time = 0.1
        time_moving = false
    elif Ref.world.current_dimension == LucidBlocksWorld.Dimension.FIRMAMENT or Ref.world.current_dimension == LucidBlocksWorld.Dimension.YHVH:
        time = 0.03
        time_moving = false
    else:
        time_moving = true
