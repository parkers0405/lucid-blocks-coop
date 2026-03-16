class_name Sheep extends Entity

@export var walk_time: float = 1.5
@export var idle_time: float = 4.0
@export var panic_time: float = 4.0
@export var random_time_range: float = 1.5

@onready var anim: AnimationTree = %SheepModel.get_node("%AnimationTree")
@onready var ambient_sound_enabled: bool = %AmbientSound.enabled

enum {IDLE, WALK, PANIC}

var state: int = IDLE
var will_jump: bool = false
var desired_direction: Vector3 = Vector3()
var desired_angle: float = 0
var last_source_position: Vector3
var panic_source


func _ready() -> void :
    super._ready()
    %Timer.start(get_time(idle_time))
    %Timer.timeout.connect(_on_timeout)
    damage_taken.connect(_on_damage_taken)
    on_attacked.connect(_on_attacked)

    anim["parameters/fear/blend_amount"] = 0.0
    anim["parameters/walk/blend_amount"] = 0.0
    anim.advance(1.0)

    desired_angle = randf_range(0, 2 * PI)
    %RotationPivot.rotation.y = desired_angle


func _on_timeout() -> void :
    if dead:
        return

    %AmbientSound.enabled = ambient_sound_enabled
    if state == PANIC:
        static_speed_modifier -= 2.0
        desired_direction = Vector3()
        state = IDLE
        %Timer.start(get_time(idle_time))
    elif state == IDLE:
        state = WALK
        var dir: Vector3 = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized()
        set_desired_direction(dir)
        %Timer.start(get_time(walk_time))
    elif state == WALK:
        desired_direction = Vector3()
        state = IDLE
        %Timer.start(get_time(idle_time))


func _physics_process(delta: float) -> void :
    if disabled or not Ref.world.is_position_loaded(global_position):
        return
    super._physics_process(delta)
    if is_future_position_loaded(delta):
        move_and_slide()

    if dead:
        desired_direction = Vector3()
    elif state == PANIC:
        if is_instance_valid(panic_source):
            last_source_position = panic_source.global_position
        var dir: Vector3 = global_position - last_source_position
        dir.y = 0
        dir = dir.normalized()
        set_desired_direction(dir)

        if is_on_floor() and %JumpRayCast.is_colliding():
            will_jump = true

        anim["parameters/fear/blend_amount"] = lerp(anim["parameters/fear/blend_amount"], 1.0, delta * 8.0)
    else:
        anim["parameters/fear/blend_amount"] = lerp(anim["parameters/fear/blend_amount"], 0.0, delta * 8.0)

    var horizontal_velocity: Vector3 = Vector3(velocity.x, 0, velocity.z)
    anim["parameters/walk/blend_amount"] = min(1.0, horizontal_velocity.length() / speed)
    %RotationPivot.rotation.y = lerp_angle( %RotationPivot.rotation.y, desired_angle, delta * 4.0)

    var jumped: bool = default_entity_movement(delta, desired_direction, ground_accel, speed * speed_modifier, will_jump, true, false)
    if jumped:
        will_jump = false


func set_desired_direction(direction: Vector3) -> void :
    desired_direction = direction

    var dir: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
    if dir.is_zero_approx():
        return

    desired_angle = atan2(dir.x, dir.z)


func get_time(time: float) -> float:
    return randf_range(time, time * random_time_range)


func _on_damage_taken(_damage: int) -> void :
    if state == PANIC:
        return

    static_speed_modifier += 2.0

    last_source_position = (global_position + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized())
    %AmbientSound.enabled = false

    %Timer.stop()
    state = PANIC
    %Timer.start(get_time(panic_time))


func _on_attacked(attacker) -> void :
    if state == PANIC:
        return

    static_speed_modifier += 2.0

    panic_source = attacker
    %AmbientSound.enabled = false

    %Timer.stop()
    state = PANIC
    %Timer.start(get_time(panic_time))


func die() -> void :
    reward_session_player_hate(panic_source, 1, 1.0)
    super.die()
    %AmbientSound.enabled = false


func preserve_save(file: SaveFile, uuid: String) -> void :
    super.preserve_save(file, uuid)
    file.set_data("node/%s/desired_angle" % uuid, desired_angle)


func preserve_load(file: SaveFile, uuid: String) -> void :
    super.preserve_load(file, uuid)
    desired_angle = file.get_data("node/%s/desired_angle" % uuid, 0)
    %RotationPivot.rotation.y = desired_angle
