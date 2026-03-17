class_name Worm extends Entity

const test_height: int = 8
const test_casts: int = 6

@export var bounce_radius: float
@export var peak_height: float = 3.0
@export var bounce_time_min: float = 2.0
@export var bounce_time_max: float = 3.0
@export var segment_delay: float = 0.02
@export var bounce_speed: float = 1.0
@export var offset: Vector3 = Vector3(0, 0.25, 0)
@export var area_scene: PackedScene
@export var min_segments: int = 4
@export var max_segments: int = 16
@export var segment_scene: PackedScene

@onready var terrain_checker: RayCast3D = %TerrainChecker
@onready var bounce_timer: Timer = %BounceTimer

var segments: Array[Node3D]
var head_segment: Node3D

var bounce_t: float = 0
var bouncing: bool = false
var bounce_source: Vector3
var bounce_peak: Vector3
var bounce_target: Vector3
var look_target: Vector3
var bounce_direction: Vector3

var first_bounce: bool = true


func _ready() -> void :
    super._ready()

    bounce_timer.timeout.connect(_on_bounce_timeout)
    bounce_timer.start(randf_range(bounce_time_min, bounce_time_max))

    var segment_count: int = randi_range(min_segments, max_segments)
    for i in range(segment_count):
        var new_segment: Node3D = segment_scene.instantiate()
        %Segments.add_child(new_segment)

    for node in %Segments.get_children():
        segments.append(node)
        node.position = offset

        var new_area: Area3D = area_scene.instantiate()
        add_child(new_area)
        new_area.owner = self
        var copy: RemoteTransform3D = RemoteTransform3D.new()
        node.add_child(copy)
        copy.remote_path = copy.get_path_to(new_area)

    head_segment = segments[0]

    bounce_target = (global_position + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)).normalized())
    look_target = get_look_target()

    SpatialMath.look_at(head_segment, look_target)

    modulate_changed.connect(_on_modulate_changed)
    alpha_changed.connect(_on_alpha_changed)


func _on_modulate_changed(new_modulate: Color) -> void :
    for segment in segments:
        segment.set("instance_shader_parameters/albedo", new_modulate)
    for segment in head_segment.get_children():
        segment.set("instance_shader_parameters/albedo", new_modulate)


func _on_alpha_changed(new_alpha: float) -> void :
    for segment in segments:
        segment.set("instance_shader_parameters/fade", new_alpha)
    for segment in head_segment.get_children():
        segment.set("instance_shader_parameters/fade", new_alpha)


func _on_bounce_timeout() -> void :
    bouncing = start_bounce()


func _physics_process(delta: float) -> void :
    if disabled or not is_session_position_loaded(global_position):
        return
    distance_process_check()

    if bouncing:
        for segment in segments:
            var t: float = clamp(bounce_t - segment.get_index() * segment_delay, 0, 1)
            segment.global_position = parabola(bounce_source, bounce_peak, bounce_target, t)
    bounce_t += bounce_speed * delta

    var average_position: Vector3 = Vector3()
    for segment in segments:
        average_position += segment.global_position
    average_position /= len(segments)
    var last_position: Vector3 = global_position
    global_position = average_position
    for segment in segments:
        segment.global_position -= average_position - last_position

    if dead:
        return

    check_fire()
    check_water()

    knockback_process(delta)
    rope_process(delta)
    gravity_process(delta)

    var new_bounce_direction: Vector3 = (bounce_target - bounce_source).normalized()

    look_target = lerp(look_target, get_look_target(), delta * 3.0)
    bounce_direction = lerp(bounce_direction, new_bounce_direction, delta * 2.0)
    SpatialMath.look_at(head_segment, look_target)

    if segments[len(segments) - 1].global_position.distance_to(bounce_target) < 0.01:
        bouncing = false

    if not bouncing:
        velocity = movement_velocity + knockback_velocity + gravity_velocity + rope_velocity

        if is_future_position_loaded(delta):
            move_and_slide()


func parabola(A: Vector3, H: Vector3, B: Vector3, t: float) -> Vector3:
    return (1.0 - t) * (1.0 - t) * A + 2.0 * (1.0 - t) * t * H + t * t * B


func get_look_target() -> Vector3:
    return bounce_target + bounce_direction * 2.0


func start_bounce() -> bool:
    bounce_timer.start(randf_range(bounce_time_min, bounce_time_max))

    if bouncing:
        return true

    var bounce_position: Vector3 = Vector3(randf() - 0.5, 0, randf() - 0.5).normalized() * bounce_radius
    var bounce_test_position: Vector3 = bounce_position + Vector3(0, test_height, 0)
    terrain_checker.global_position = get_root_position() + bounce_test_position
    terrain_checker.target_position = - Vector3(0, 2 * test_height, 0)
    terrain_checker.force_raycast_update()

    if not terrain_checker.is_colliding():
        return false

    bounce_t = 0.0

    var temp_source: Vector3 = get_root_position()
    var temp_target: Vector3 = terrain_checker.get_collision_point() + offset
    var temp_peak: Vector3 = (temp_source + temp_target) * 0.5 + Vector3(0, peak_height, 0)

    for i in range(test_casts - 1):
        var t_start: float = i / float(test_casts)
        var t_end: float = (i + 1) / float(test_casts)
        var test_start: Vector3 = parabola(temp_source, temp_peak, temp_target, t_start)
        var test_end: Vector3 = parabola(temp_source, temp_peak, temp_target, t_end)
        terrain_checker.global_position = test_start
        terrain_checker.target_position = test_end - test_start
        terrain_checker.force_raycast_update()
        if terrain_checker.is_colliding():
            return false

    bounce_source = temp_source
    bounce_target = temp_target
    bounce_peak = temp_peak

    first_bounce = false

    %BouncePlayer.play()

    return true


func get_root_position() -> Vector3:
    return head_segment.global_position
