class_name Wildebeest extends Entity

@export var attack_anger: float = 1.0
@export var trespass_anger: float = 0.01
@export var anger_threshold: float = 1.0
@export var bothersome_limit: int = 10
@export var run_accel: float = 1.0
@export var walk_accel: float = 2.0
@export var run_max_speed_multiplier: float = 2.0
@export var direction_punish: float = 0.4
@export var random_time_range: float = 3.0
@export var min_idle_time: float = 4.5
@export var min_walk_time: float = 2.0
@export var min_attack_speed: float = 5.0

@onready var anim: AnimationTree = %WildebeestModel.get_node("%AnimationTree")

enum {IDLE, WALK, CHASE}


var player
var state: int = IDLE
var anger: float = 0.0
var bothersome_entities: Array[Entity]
var bothersome: Entity
var attacker: Entity


var interest_place: Vector3
var actual_direction: Vector3
var desired_direction: Vector3
var desired_angle: float = 0.0
var direction_to_player: Vector3
var will_jump: bool = false
var run_amount: float = 0.0
var walk_amount: float = 0.0
var run_speed_multiplier: float = 1.0
var chase_initial_direction_set: bool = false


func _ready() -> void :
    super._ready()

    desired_angle = randf_range(0, 2 * PI)
    %RotationPivot.rotation.y = desired_angle

    anim["parameters/walk/blend_amount"] = 0.0
    anim["parameters/run/blend_amount"] = 0.0

    %DetectionArea3D.body_entered.connect(_on_body_entered)
    %DetectionArea3D.body_exited.connect(_on_body_exited)

    damage_taken.connect(_on_damage_taken)

    %IdleTimer.start(get_time(min_idle_time))
    %IdleTimer.timeout.connect(_on_idle_timeout)
    %WalkTimer.timeout.connect(_on_walk_timeout)

    %AttackArea3D.body_entered.connect(_on_body_entered_attack)
    %AttackArea3D.body_entered.connect(_on_body_exited_attack)


func _on_body_entered_attack(body: Node3D) -> void :
    if state != CHASE or dead or disabled:
        return
    if body == self:
        return
    if Vector3(movement_velocity.x, 0, movement_velocity.z).length() > min_attack_speed:
        %Attack.attack(body, body.global_position, 48.0, 1.2)


func _on_body_exited_attack(_body: Node3D) -> void :
    if state != CHASE or dead or disabled:
        return


func _on_idle_timeout() -> void :
    if dead or not is_inside_tree():
        return

    if state == IDLE:
        desired_direction = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized()
        %IdleTimer.start(get_time(min_idle_time))
        %WalkTimer.start(get_time(min_walk_time))
        switch_state(WALK)


func _on_walk_timeout() -> void :
    if dead or not is_inside_tree():
        return

    if state == WALK:
        switch_state(IDLE)


func _on_damage_taken(damage: int) -> void :
    if damage > 0:
        anger += attack_anger * damage
        anim["parameters/hurt/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE


func _on_body_entered(body: Node3D) -> void :
    if len(bothersome_entities) > bothersome_limit:
        return
    if body is Wildebeest:
        return
    bothersome_entities.append(body)
    update_bothersome_target()


func _on_body_exited(body: Node3D) -> void :
    var index: int = bothersome_entities.find(body)
    if index != -1:
        bothersome_entities.remove_at(index)
    update_bothersome_target()


func update_bothersome_target() -> void :
    bothersome = null

    bothersome_entities.shuffle()
    if len(bothersome_entities) == 0:
        return

    for entity in bothersome_entities:
        var preferred_session_target: bool = is_session_player_entity(entity) and not bothersome is Bubblebear
        if entity == attacker or (bothersome != attacker and (preferred_session_target or entity is Bubblebear)):
            bothersome = entity

    if bothersome == null:
        bothersome = bothersome_entities.pick_random()


func _on_attacked(new_attacker: Entity) -> void :
    if is_instance_valid(new_attacker):
        bothersome = new_attacker
        anger += attack_anger


func _physics_process(delta: float) -> void :
    if disabled or not is_session_position_loaded(global_position):
        return
    super._physics_process(delta)
    if is_future_position_loaded(delta):
        move_and_slide()

    if dead:
        run_amount = lerp(run_amount, 0.0, clamp(delta * run_accel, 0.0, 1.0))
        walk_amount = lerp(walk_amount, 0.0, clamp(delta * walk_accel, 0.0, 1.0))
        desired_direction = Vector3()
        actual_direction = Vector3()

    var horizontal_movement: Vector3 = Vector3(movement_velocity.x, 0, movement_velocity.z)

    if state == CHASE:
        chase_process(delta)
    if state == IDLE:
        idle_process(delta)
    if state == WALK:
        walk_process(delta)

    actual_direction = actual_direction.slerp(desired_direction, delta * 2 * (1.2 + desired_direction.dot(actual_direction)))

    var direction_dot: float = (actual_direction.dot( %RotationPivot.basis.z) + 1.0) / 2.0
    var direction_alignment: float = lerp(direction_punish, 1.0, direction_dot)
    var target_speed: float = speed * speed_modifier * direction_alignment * walk_amount * lerp(1.0, run_max_speed_multiplier, run_amount)
    var jumped: bool = default_entity_movement(delta, actual_direction, ground_accel, target_speed, will_jump, true, false)

    if jumped:
        will_jump = false

    var speed_alignment: float = clamp(horizontal_movement.length() / speed, 0.0, 1.0)
    anim["parameters/walk/blend_amount"] = lerp(anim["parameters/walk/blend_amount"], speed_alignment, clamp(delta * walk_accel, 0.0, 1.0))
    anim["parameters/run/blend_amount"] = (run_amount * lerp(anim["parameters/run/blend_amount"], clamp(horizontal_movement.length() / (speed * run_max_speed_multiplier), 0.0, 1.0), clamp(delta * run_accel, 0.0, 1.0)))

    look_at_desired_direction(actual_direction)
    %RotationPivot.rotation.y = lerp_angle( %RotationPivot.rotation.y, desired_angle, delta * 4.0)

    %GallopPlayer.volume_linear = speed_alignment * 0.01


func idle_process(delta: float) -> void :
    run_amount = lerp(run_amount, 0.0, clamp(delta * run_accel, 0.0, 1.0))
    walk_amount = lerp(walk_amount, 0.0, clamp(delta * walk_accel, 0.0, 1.0))

    anger += trespass_anger * len(bothersome_entities) * delta

    if anger > anger_threshold:
        switch_state(CHASE)


func walk_process(delta: float) -> void :
    idle_process(delta)
    run_amount = lerp(run_amount, 0.0, clamp(delta * run_accel, 0.0, 1.0))
    walk_amount = lerp(walk_amount, 1.0, clamp(delta * walk_accel, 0.0, 1.0))

    anger += trespass_anger * len(bothersome_entities) * delta

    if anger > anger_threshold:
        switch_state(CHASE)


func chase_process(delta: float) -> void :
    if not is_instance_valid(bothersome) or bothersome.dead or not is_inside_tree():
        switch_state(IDLE)
        return

    run_amount = lerp(run_amount, 1.0, clamp(delta * run_accel, 0.0, 1.0))
    walk_amount = lerp(walk_amount, 1.0, clamp(delta * walk_accel, 0.0, 1.0))

    if is_on_floor() and %JumpRayCast3D.is_colliding() and run_amount >= 0.2:
        will_jump = true

    var difference_vector: Vector3 = bothersome.global_position - global_position
    difference_vector.y = 0.0

    var horizontal_movement: Vector3 = Vector3(movement_velocity.x, 0, movement_velocity.z)
    var speed_alignment: float = clamp(horizontal_movement.length() / (speed * run_max_speed_multiplier), 0.0, 1.0)

    if not chase_initial_direction_set or (difference_vector.length() >= 3.0 + 24.0 * (actual_direction.dot(desired_direction) - 0.1)):
        desired_direction = difference_vector.normalized()
        chase_initial_direction_set = true

    if %CrashRayCast3D.is_colliding() or is_on_wall():
        desired_direction = - %RotationPivot.basis.z.normalized()
        run_amount = lerp(run_amount, 0.0, clamp(delta * run_accel * 4.0, 0.0, 1.0))

    if desired_direction.dot(actual_direction) >= 0.8 and speed_alignment >= 0.8 and is_on_wall() and %CrashRayCast3D.is_colliding():
        crash()


func crash() -> void :
    run_amount = 0.0
    chase_initial_direction_set = false
    take_damage(1, FALL)


func switch_state(new_state: int) -> void :
    state = new_state
    if state == IDLE:
        %IdleTimer.start(get_time(min_idle_time))
    if state == CHASE:
        chase_initial_direction_set = false


func look_at_desired_direction(direction: Vector3) -> void :
    if dead:
        return

    var dir: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
    if dir.is_zero_approx():
        return

    desired_angle = atan2(dir.x, dir.z)


func get_time(time: float) -> float:
    return randf_range(time, time * random_time_range)
