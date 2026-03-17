class_name Chicken extends Entity

@export var walk_time: float = 1.5
@export var idle_time: float = 4.0
@export var panic_time: float = 4.0
@export var random_time_range: float = 1.5
@export var turn_accel: float = 4.0
@export var follow_distance: float = 8.0
@export var follow_chance: float = 0.5
@export var follow_limit: int = 10
@export var follow_random_radius: float = 3.0
@export var follow_near_threshold: float = 1.5
@export var leader_chance: float = 0.15

@onready var anim: AnimationTree = %ChickenModel.get_node("%AnimationTree")

enum {IDLE, WALK, PANIC, FOLLOW}

var state: int = IDLE
var will_jump: bool = false
var desired_direction: Vector3
var desired_angle: float
var last_source_position: Vector3
var panic_source: Entity

var follow_entities: Array[Entity]
var follow: Entity
var follow_position: Vector3
var follow_offset: Vector3
var leader: bool


func _ready() -> void :
    hand = %ChickenModel.get_node("%Hand")
    head = %ChickenModel.get_node("%Head")

    super._ready()

    %StateTimer.start(get_time(idle_time))
    %StateTimer.timeout.connect(_on_timeout)

    damage_taken.connect(_on_damage_taken)
    on_attacked.connect(_on_attacked)

    anim["parameters/fear/blend_amount"] = 0.0
    anim["parameters/walk/blend_amount"] = 0.0
    anim.advance(1.0)

    desired_angle = randf_range(0, 2 * PI)
    %RotationPivot.rotation.y = desired_angle

    %FollowArea.body_entered.connect(_on_body_entered)
    %FollowArea.body_exited.connect(_on_body_exited)

    leader = randf() < leader_chance


func _on_body_entered(body: Node3D) -> void :
    if len(follow_entities) > follow_limit:
        return
    follow_entities.append(body)
    update_follow_target()


func _on_body_exited(body: Node3D) -> void :
    var index: int = follow_entities.find(body)
    if index != -1:
        follow_entities.remove_at(index)
    update_follow_target()


func update_follow_target() -> void :
    follow = null

    follow_entities.shuffle()
    if len(follow_entities) == 0:
        return
    for entity in follow_entities:
        if health == max_health and not entity is Chicken:
            follow = entity

    if follow == null:
        follow = follow_entities.pick_random()


func _on_timeout() -> void :
    if dead:
        return

    %AmbientSound.enabled = true
    if state == PANIC:
        static_speed_modifier -= 1.0
        desired_direction = Vector3()
        state = IDLE
        %StateTimer.start(get_time(idle_time))
    elif state == FOLLOW:
        %StateTimer.start(get_time(idle_time))
        if not is_instance_valid(follow):
            state = IDLE
        else:
            follow_offset = (follow_random_radius * Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)))
            follow_position = follow.global_position + follow_offset
        if randf() < follow_chance:
            update_follow_target()
    elif state == IDLE:
        state = WALK
        var dir: Vector3 = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized()
        set_desired_direction(dir)
        %StateTimer.start(get_time(walk_time))

        if randf() < follow_chance and is_instance_valid(follow):
            state = FOLLOW
            follow_position = follow.global_position
    elif state == WALK:
        desired_direction = Vector3()
        state = IDLE
        %StateTimer.start(get_time(idle_time))


func _physics_process(delta: float) -> void :
    if disabled or not is_session_position_loaded(global_position):
        return
    super._physics_process(delta)
    if is_future_position_loaded(delta):
        move_and_slide()

    if dead:
        desired_direction = Vector3()
    elif state == PANIC:
        if is_instance_valid(panic_source):
            last_source_position = panic_source.global_position
        var away_from_harm_direction: Vector3 = global_position - last_source_position
        away_from_harm_direction.y = 0
        away_from_harm_direction = away_from_harm_direction.normalized()
        set_desired_direction(away_from_harm_direction)

        if is_on_floor() and %JumpRayCast.is_colliding():
            will_jump = true

    elif state == FOLLOW:
        var towards_follow_position: Vector3
        if is_instance_valid(follow):
            towards_follow_position = follow.global_position + follow_offset - global_position
        else:
            towards_follow_position = follow_position - global_position

        if towards_follow_position.length() < follow_near_threshold:
            desired_direction = Vector3()
        else:
            towards_follow_position.y = 0
            towards_follow_position = towards_follow_position.normalized()
            set_desired_direction(towards_follow_position)

        if is_on_floor() and %JumpRayCast.is_colliding():
            will_jump = true

    if state == PANIC:
        anim["parameters/fear/blend_amount"] = lerp(anim["parameters/fear/blend_amount"], 1.0, delta * 8.0)
    else:
        anim["parameters/fear/blend_amount"] = lerp(anim["parameters/fear/blend_amount"], 0.0, delta * 8.0)

    var horizontal_velocity: Vector3 = Vector3(velocity.x, 0, velocity.z)
    anim["parameters/walk/blend_amount"] = min(1.0, horizontal_velocity.length() / (speed * speed_modifier))
    %RotationPivot.rotation.y = lerp_angle( %RotationPivot.rotation.y, desired_angle, clamp(delta * turn_accel, 0.0, 1.0))

    var jumped: bool = default_entity_movement(delta, desired_direction, ground_accel, speed * speed_modifier, will_jump, true, false)
    if jumped:
        will_jump = false


func set_desired_direction(direction: Vector3) -> void :
    if dead:
        return

    var dir: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
    if dir.is_zero_approx():
        return

    desired_direction = dir
    desired_angle = atan2(dir.x, dir.z)


func get_time(time: float) -> float:
    return randf_range(time, time * random_time_range)


func _on_damage_taken(_damage: int) -> void :
    if state == PANIC:
        return

    static_speed_modifier += 1.0

    last_source_position = (global_position + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized())
    %AmbientSound.enabled = false

    %StateTimer.stop()
    state = PANIC
    %StateTimer.start(get_time(panic_time))


func _on_attacked(attacker: Entity) -> void :
    if state == PANIC:
        return

    static_speed_modifier += 1.0

    panic_source = attacker
    %AmbientSound.enabled = false

    %StateTimer.stop()
    state = PANIC
    %StateTimer.start(get_time(panic_time))


func die() -> void :
    if panic_source == Ref.player:
        if randf() < 0.2:
            Ref.player.hate += 1

    super.die()
    %AmbientSound.enabled = false


func preserve_save(file: SaveFile, uuid: String) -> void :
    super.preserve_save(file, uuid)
    file.set_data("node/%s/desired_angle" % uuid, desired_angle)
    file.set_data("node/%s/leader" % uuid, leader)


func preserve_load(file: SaveFile, uuid: String) -> void :
    super.preserve_load(file, uuid)
    desired_angle = file.get_data("node/%s/desired_angle" % uuid, 0)
    leader = file.get_data("node/%s/leader" % uuid, leader)
    %RotationPivot.rotation.y = desired_angle
