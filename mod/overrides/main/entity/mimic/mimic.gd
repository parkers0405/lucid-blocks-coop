class_name Mimic extends Blasphemy

enum {IDLE, CHASE}

@export var default_block: Block
@export var awaken_chance: float = 0.5
@export var fast_multiplier: float = 2.5
@export var fast_chance: float = 0.1
@export var default_death_drop: Loot

var state: int = IDLE
var copy_block: Block:
    set(val):
        copy_block = val
        if is_instance_valid(copy_block):
            pickaxe_weakness = copy_block.pickaxe_affinity
            axe_weakness = copy_block.axe_affinity
        else:
            pickaxe_weakness = false
            axe_weakness = false
var fast: bool = false


func _ready() -> void :
    super._ready()
    transform.origin = transform.origin.floor() + Vector3(0.5, 0, 0.5)
    while is_session_position_loaded(transform.origin.floor()) and Ref.world.is_block_solid_at(transform.origin.floor()):
        transform.origin.y += 1
    copy_block = capture_block()

    fast = randf() < fast_chance

    initialize_state()


func _is_session_player_body(body: Node3D) -> bool:
    return is_session_player_entity(body)


func _on_body_entered_attack(body: Node3D) -> void :
    super._on_body_entered_attack(body)
    if body == self or dead or state == CHASE or disabled:
        return

    if state == IDLE and _is_session_player_body(body) and randf() < awaken_chance:
        state = CHASE
        initialize_state()


func _on_attacked(_attacker) -> void :
    if state != CHASE:
        state = CHASE
        initialize_state()


func _get_session_attack_target():
    return get_session_target_entity(Ref.player)


func _on_attack_timeout() -> void :
    if dead or disabled:
        return
    if not state == CHASE:
        return
    var target = _get_session_attack_target()
    if not is_instance_valid(target) or target.dead:
        return

    var target_head: Vector3 = target.head.global_position if is_instance_valid(target.head) else target.global_position + Vector3(0, 1.45, 0)
    var target_direction: Vector3 = head.to_local(target_head).normalized()
    thrust(target_direction)

    if target.global_position.distance_to(global_position + target_direction) < attack_distance:
        %Attack.attack(target, target.global_position, 30.0)


func thrust(target_direction: Vector3) -> void :
    var tween: Tween = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
    tween.tween_property( %Core, "position", target_direction * 1.5, 0.05)
    tween.tween_property( %Core, "position", Vector3(), 0.3)
    %WhiffPlayer3D.play()

func capture_block() -> Block:
    var block_position: Vector3 = global_position.floor() - Vector3(0, 1, 0)
    if not is_session_position_loaded(block_position) or not Ref.world.is_block_solid_at(block_position):
        return default_block
    var block_type: Block = Ref.world.get_block_type_at(block_position)
    if block_type.internal_name == "cutscene block" or block_type.internal_name == "respawn block" or block_type.textureless:
        return default_block
    return block_type


func update_block() -> void :
    %ThudPainSound.sound = copy_block.step_sound
    %PainSound.sound = copy_block.break_sound
    %Core.set_instance_shader_parameter("index", copy_block.get_index())


    death_drop = default_death_drop.duplicate()
    death_drop.items = death_drop.items.duplicate()
    if copy_block.drop_loot != null:
        var leg_item: Item = death_drop.items[0]
        var leg_count_drop: int = death_drop.counts[0]
        var leg_chance: float = death_drop.chances[0]

        death_drop = copy_block.drop_loot.duplicate()

        death_drop.items = death_drop.items.duplicate()
        death_drop.items.append(leg_item)

        var counts: PackedInt32Array = death_drop.counts.duplicate()
        counts.push_back(leg_count_drop)
        death_drop.counts = counts

        var chances: PackedFloat32Array = death_drop.chances.duplicate()
        chances.push_back(leg_chance)
        death_drop.chances = chances
    elif copy_block.directional and copy_block.can_drop:
        death_drop.items[1] = copy_block.drop_item if is_instance_valid(copy_block.drop_item) else copy_block
    elif copy_block.drop_item != null:
        death_drop.items[1] = copy_block.drop_item
    elif not copy_block.internal:
        death_drop.items[1] = copy_block


func preserve_save(file: SaveFile, uuid: String) -> void :
    super.preserve_save(file, uuid)
    file.set_data("node/%s/state" % uuid, state)
    file.set_data("node/%s/copy_id" % uuid, copy_block.id)
    file.set_data("node/%s/fast" % uuid, fast)


func preserve_load(file: SaveFile, uuid: String) -> void :
    super.preserve_load(file, uuid)
    state = file.get_data("node/%s/state" % uuid, 0)
    copy_block = ItemMap.map(file.get_data("node/%s/copy_id" % uuid, default_block.id))
    fast = file.get_data("node/%s/fast" % uuid, false)
    initialize_state()


func _physics_process(delta: float) -> void :
    if disabled or not is_session_position_loaded(global_position):
        return
    distance_process_check()

    if state == CHASE:
        var results: Array[float] = leg_process()
        var total_displacement: float = results[0]
        var applying_force: float = results[1]

        spring_process(delta, total_displacement, applying_force)

        velocity = movement_velocity + gravity_velocity + knockback_velocity + rope_velocity

        if is_future_position_loaded(delta):
            move_and_slide()

        rope_process(delta)
        gravity_process(delta)
        knockback_process(delta)

        var vertical_movement_velocity: float = movement_velocity.y
        movement_velocity = lerp(movement_velocity, desired_velocity, min(1.0, delta * ground_accel))
        movement_velocity.y = vertical_movement_velocity

        var target = _get_session_attack_target()
        if not is_instance_valid(target) or target.dead:
            desired_velocity = Vector3()
            return

        var dir: Vector3 = (target.global_position - global_position).normalized()
        dir.y = 0
        desired_velocity.x = dir.x * speed * (fast_multiplier if fast else 1.0)
        desired_velocity.z = dir.z * speed * (fast_multiplier if fast else 1.0)
    else:
        while is_session_position_loaded(global_position) and Ref.world.is_block_solid_at(global_position):
            global_position.y += 1


func initialize_state() -> void :
    if state == IDLE:
        for leg in legs:
            leg.visible = false
        %CollisionShape3D.position.y = 0.5
    elif state == CHASE:
        for leg in legs:
            leg.visible = true
        %CollisionShape3D.position.y = 0.25
    update_block()
