class_name Diatom extends Blasphemy

enum {IDLE, CHASE}

signal shoot_frame

@export var starting_items: Array[Item]
@export var awaken_chance: float = 0.5

var state: int = IDLE
var chase_target: Entity
var brain_flow: float = 0.0


func _ready() -> void :
    super._ready()

    var item: Item = starting_items.pick_random()
    var new_item_state: ItemState = ItemState.new()
    new_item_state.initialize(item)
    new_item_state.count = min(item.stack_size, 30)
    held_item_inventory.set_item(0, new_item_state)

    brain_flow = randf_range(0, 100)

    initialize_state()


func _on_body_entered_attack(body: Node3D) -> void :
    super._on_body_entered_attack(body)
    if body == self or dead or state == CHASE or disabled:
        return

    if state == IDLE and body is Entity and randf() < awaken_chance:
        state = CHASE
        chase_target = body
        initialize_state()


func _on_attacked(attacker: Entity) -> void :
    if state != CHASE:
        chase_target = attacker
        state = CHASE
        initialize_state()


func _on_attack_timeout() -> void :
    if dead or disabled:
        return
    if not state == CHASE:
        return
    if not is_instance_valid(chase_target):
        return
    var target_direction: Vector3 = head.to_local(chase_target.head.global_position).normalized()
    if chase_target.global_position.distance_to(global_position + target_direction) < attack_distance:
        attack()


func preserve_save(file: SaveFile, uuid: String) -> void :
    super.preserve_save(file, uuid)
    file.set_data("node/%s/state" % uuid, state)


func preserve_load(file: SaveFile, uuid: String) -> void :
    super.preserve_load(file, uuid)
    state = file.get_data("node/%s/state" % uuid, 0)
    initialize_state()


func _physics_process(delta: float) -> void :
    if disabled or not is_session_position_loaded(global_position):
        return
    distance_process_check()
    if is_future_position_loaded(delta):
        move_and_slide()

    brain_flow += delta

    var direction: Vector3 = Vector3(movement_velocity.x, 0, movement_velocity.z).normalized()
    SpatialMath.look_at_local( %LegRests, direction)
    SpatialMath.look_at_local( %LegRays, direction)
    SpatialMath.look_at_local( %Core, direction)

    var results: Array[float] = leg_process()
    var total_displacement: float = results[0]
    var applying_force: float = results[1]

    spring_process(delta, total_displacement, applying_force)

    velocity = movement_velocity + gravity_velocity + knockback_velocity + rope_velocity

    rope_process(delta)
    gravity_process(delta)
    knockback_process(delta)

    var vertical_movement_velocity: float = movement_velocity.y
    movement_velocity = lerp(movement_velocity, desired_velocity, min(1.0, delta * ground_accel))
    movement_velocity.y = vertical_movement_velocity

    if state == CHASE:
        if is_instance_valid(chase_target):
            var dir: Vector3 = (chase_target.global_position - global_position).normalized()
            dir.y = 0
            desired_velocity.x = dir.x * speed
            desired_velocity.z = dir.z * speed
        else:
            state = IDLE
    if state == IDLE:
        desired_velocity = (speed * (Vector3(sin(brain_flow * 0.25 + cos(brain_flow * 0.1)), 0, cos(brain_flow * 0.25 + sin(brain_flow * 0.3))).normalized()))


func attack() -> void :
    if dead or not is_inside_tree() or disabled:
        return
    %AttackAnimationPlayer.play("attack")
    await shoot_frame
    throw_bomb()


func throw_bomb() -> void :
    if not is_interacting() and is_instance_valid(held_item):
        var can_interact_using_item: bool = is_instance_valid(held_item) and held_item.can_interact({})
        var _success: bool = can_interact_using_item and await held_item.interact(true, {})
        if is_interacting():
            held_item.interact_end()


func initialize_state() -> void :
    if state == IDLE:
        %AttackTimer.stop()
    elif state == CHASE:
        %AttackTimer.start(attack_timeout)


func get_look_direction() -> Vector3:
    return - %Core.get_global_transform().basis.z
