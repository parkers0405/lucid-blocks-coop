class_name Sunny extends Entity

@export var petal_scene: PackedScene
@export var min_petal_count: int = 6
@export var max_petal_count: int = 11
@export var petal_radius: float = 0.275
@export var min_target_distance: float = 8.0
@export var max_target_distance: float = 24.0
@export var found_target_distance: float = 3.0
@export var idle_time_min: float = 6.0
@export var idle_time_max: float = 12.0

@onready var head_segment: Node3D = %HeadSegment

var petals: Array[Node3D]

var petal_count: int = 0
var state: int
var target_location: Vector3
var time: float
var spin_speed: float = 1.0
var spin_accel: float
var personality: float = 1.0

var direction: Vector3
var desired_direction: Vector3
var crashed: bool = false

enum {IDLE, LOCATE}


func _ready() -> void :
    super._ready()
    petal_count = randi_range(min_petal_count, max_petal_count)
    create_petal_count()

    modulate_changed.connect(_on_modulate_changed)
    alpha_changed.connect(_on_alpha_changed)

    on_attacked.connect(_on_attacked)

    %StateTimer.timeout.connect(_on_state_timeout)

    personality = randf_range(0.9, 1.1) * sign(randf_range(-1, 1))

    state = IDLE
    initialize_state()


func _on_modulate_changed(new_modulate: Color) -> void :
    for petal in petals:
        petal.set("instance_shader_parameters/albedo", new_modulate)
    for segment in head_segment.get_children():
        segment.set("instance_shader_parameters/albedo", new_modulate)


func _on_alpha_changed(new_alpha: float) -> void :
    for petal in petals:
        petal.set("instance_shader_parameters/fade", new_alpha)
    for segment in head_segment.get_children():
        segment.set("instance_shader_parameters/fade", new_alpha)


func _on_state_timeout() -> void :
    if state == IDLE:
        state = LOCATE
        initialize_state()


func _on_attacked(_attacker: Entity) -> void :
    if state == IDLE:
        state = LOCATE
        initialize_state()
        spin_accel += 16.0


func _physics_process(delta: float) -> void :
    if disabled or not is_session_position_loaded(global_position):
        return
    distance_process_check()

    time += clamp(delta * personality, 0.0, 1.0)
    spin_speed += clamp(spin_accel * delta, 0.0, 1.0)
    %RotationPivot.rotate_y(clamp(spin_speed * delta, 0.0, 1.0))

    spin_accel = lerp(spin_accel, 0.0, clamp(delta, 0.0, 1.0))
    if spin_speed > 1.0:
        spin_speed = lerp(spin_speed, 1.0, clamp(delta, 0.0, 1.0))

    check_fire()
    check_water()

    var target_direction: Vector3
    if state == IDLE:
        target_direction = (Vector3(sin(time * 2.0) * 0.2 + cos(time * 3.0) * 0.3, 0.02 + 0.05 * sin(time) + 0.1 * cos(time * 2.0), 0.2 * sin(2.0 * time) - 0.4 * cos(time)).normalized())
    else:
        target_direction = global_position.direction_to(target_location)
        if crashed or global_position.distance_to(target_location) < found_target_distance:
            state = IDLE
            initialize_state()
    crashed = false

    %ObstructionRayCast3D.target_position = desired_direction
    %ObstructionRayCast3D.force_raycast_update()
    if %ObstructionRayCast3D.is_colliding():
        desired_direction = - desired_direction
        crashed = true

    desired_direction = lerp(desired_direction, target_direction, clamp(delta, 0.0, 1.0))
    direction = lerp(direction, desired_direction, clamp(delta, 0.0, 1.0))

    movement_velocity = direction * speed

    knockback_process(delta)
    rope_process(delta)

    velocity = movement_velocity + knockback_velocity + rope_velocity
    if is_future_position_loaded(delta):
        move_and_slide()


func initialize_state() -> void :
    if state == IDLE:
        %StateTimer.start(randf_range(idle_time_min, idle_time_max))
    if state == LOCATE:
        %StateTimer.stop()
        pick_target()


func pick_target() -> void :
    var distance: float = randf_range(min_target_distance, max_target_distance)
    target_location = (global_position + (distance * Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()))


func create_petal_count() -> void :
    for petal in petals:
        petal.queue_free()
    petals.clear()
    for i in range(petal_count):
        var petal: Node3D = petal_scene.instantiate()
        %Petals.add_child(petal)
        petals.append(petal)
        var petal_plane_position: Vector2 = Vector2( - petal_radius, 0).rotated(2 * PI * i / petal_count)
        petal.position = Vector3(petal_plane_position.x, petal_plane_position.y, 0)


func preserve_save(file: SaveFile, uuid: String) -> void :
    super.preserve_save(file, uuid)
    file.set_data("node/%s/petal_count" % uuid, petal_count)


func preserve_load(file: SaveFile, uuid: String) -> void :
    super.preserve_load(file, uuid)
    petal_count = file.get_data("node/%s/petal_count" % uuid, randi_range(min_petal_count, max_petal_count))
    create_petal_count()
