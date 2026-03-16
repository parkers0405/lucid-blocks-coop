class_name Golem extends Entity

const BUILD_INDEX: int = 0
const WEAPON_INDEX: int = 1

enum {IDLE, BUILD, DEFENSE}

@export var always_angry: bool = false
@export var starting_build_items: Array[Item]
@export var starting_weapon_items: Array[Item]
@export var direction_punish: float = 0.4
@export var interact_distance: float = 3.0
@export var look_ahead_distance: float = 5.0
@export var melee_delay: float = 0.6
@export var defense_speed_multiplier: float = 2.0
@export var block_count: int = 30
@export var nearby_entity_count: int = 8

@onready var attack_timer: Timer = %AttackTimer
@onready var action_timer: Timer = %ActionTimer
@onready var model: EntityModel = %GolemModel
@onready var anim: AnimationTree = %GolemModel.get_node("%AnimationTree")

@onready var attack_shape: ShapeCast3D = %AttackShape
@onready var interact_ray: RayCast3D = %InteractRayCast3D
@onready var entity_detect: Area3D = %EntityDetect

var state: int = IDLE

var will_jump: bool = false
var desired_direction: Vector3 = Vector3(0, 0, 0)
var look_target: Vector3
var desired_angle: float = 0.0

var attack_target
var nearby_entities: Array = []


func _ready() -> void :
    speed *= randf_range(0.9, 1.1)
    hand = model.get_node("%Hand")
    head = model.get_node("%Head")

    attack_timer.timeout.connect(_on_attack_timeout)

    super._ready()

    if len(starting_build_items) > 0:
        var build_item: Item = starting_build_items.pick_random()
        var new_item_state: ItemState = ItemState.new()
        new_item_state.initialize(build_item)
        new_item_state.count = min(build_item.stack_size, block_count)
        held_item_inventory.set_item(BUILD_INDEX, new_item_state)

    if len(starting_weapon_items) > 0:
        var weapon_item: Item = starting_weapon_items.pick_random()
        var new_item_state: ItemState = ItemState.new()
        new_item_state.initialize(weapon_item)
        if weapon_item is Tool or weapon_item is Wand:
            new_item_state.durability = randi_range(1, weapon_item.max_durability / 2)
        held_item_inventory.set_item(WEAPON_INDEX, new_item_state)

    initialize_state()

    action_timer.timeout.connect(_on_action_timeout)
    action_timer.start(randf_range(2.0, 3.0))

    on_attacked.connect(_on_attacked)

    entity_detect.body_entered.connect(_on_entity_entered)
    entity_detect.body_exited.connect(_on_entity_exited)

    if always_angry:
        hold_item(WEAPON_INDEX)


func _has_session_player_target() -> bool:
    return _use_server_session_targeting() and is_session_target_within(process_distance)


func _is_session_player_entity(entity) -> bool:
    return is_session_player_entity(entity)


func _get_priority_attack_target():
    var nearest = null
    var nearest_player = null

    for entity in nearby_entities:
        if not is_instance_valid(entity) or entity.dead or entity.disabled:
            continue

        if nearest == null or entity.global_position.distance_squared_to(global_position) < nearest.global_position.distance_squared_to(global_position):
            nearest = entity
        if _is_session_player_entity(entity) and (nearest_player == null or entity.global_position.distance_squared_to(global_position) < nearest_player.global_position.distance_squared_to(global_position)):
            nearest_player = entity

    if is_instance_valid(nearest_player):
        return nearest_player
    if _has_session_player_target() and Ref.coop_manager != null:
        var session_target = Ref.coop_manager.get_nearest_session_player_entity(global_position, nearest)
        if is_instance_valid(session_target) and not session_target.dead and not session_target.disabled:
            return session_target
    return nearest


func _get_target_position() -> Vector3:
    return get_session_target_position(attack_target.global_position if is_instance_valid(attack_target) else global_position)


func _get_target_head_position() -> Vector3:
    var fallback: Vector3 = global_position + Vector3(0, 1.45, 0)
    if is_instance_valid(attack_target) and is_instance_valid(attack_target.head):
        fallback = attack_target.head.global_position
    return get_session_target_head_position(fallback)


func _on_entity_entered(entity: Node3D) -> void :
    flush_deleted_entities()
    if nearby_entities.size() < nearby_entity_count and not entity is Golem and not entity is Yhvh and not entity is Mimic:
        nearby_entities.push_back(entity)


func _on_entity_exited(entity: Node3D) -> void :
    flush_deleted_entities()
    if is_instance_valid(entity):
        var index: int = nearby_entities.find(entity)
        if index >= 0:
            nearby_entities.remove_at(index)


func _on_attacked(attacker) -> void :
    attack_target = attacker
    state = DEFENSE
    initialize_state()


func _on_action_timeout() -> void :
    if state == BUILD:
        var x: float = randf()
        if x < 0.3:
            await build_ahead()
        elif x < 0.8:
            await ascend()
        else:
            await random_walk()
        action_timer.start(randf_range(0.8, 1.5))

        var y: float = randf()
        if y < 0.12 or held_item == null:
            state = IDLE
            initialize_state()
    elif state == IDLE:
        var x: float = randf()
        if desired_direction.is_zero_approx() and x < 0.7:
            await random_walk()

        action_timer.start(randf_range(1.0, 4.0))

        var y: float = randf()
        if y < 0.2 and held_item != null:
            state = BUILD
            initialize_state()
    else:
        action_timer.start(randf_range(1.0, 2.0))


func _on_attack_timeout() -> void :
    if dead or state != DEFENSE:
        return
    attack()


func flush_deleted_entities() -> void :
    var new_entities: Array = []
    for entity in nearby_entities:
        if is_instance_valid(entity):
            new_entities.append(entity)
    nearby_entities = new_entities


func _physics_process(delta: float) -> void :
    if disabled or not is_session_position_loaded(global_position):
        return
    super._physics_process(delta)
    if is_future_position_loaded(delta):
        move_and_slide()

    if dead:
        desired_direction = Vector3()

    if always_angry:
        if len(nearby_entities) == 0 and not _has_session_player_target():
            if state == DEFENSE:
                state = IDLE
                desired_direction = Vector3()
                initialize_state()
        else:
            attack_target = _get_priority_attack_target()
            if state != DEFENSE:
                state = DEFENSE
                initialize_state()

    if state == DEFENSE:
        if not is_instance_valid(attack_target):
            attack_target = _get_priority_attack_target()
        if not is_instance_valid(attack_target) and not _has_session_player_target():
            state = IDLE
            desired_direction = Vector3()
        else:
            desired_direction = head.global_position.direction_to(_get_target_head_position())
            look_target = head.global_position + desired_direction
            look_at_direction(desired_direction)

            if is_instance_valid(attack_target) and attack_target.global_position.distance_to(global_position) < 3.0:
                attack()

    var direction_alignment: float = lerp(direction_punish, 1.0, (desired_direction.dot(rotation_pivot.basis.z) + 1.0) / 2.0)
    if dead:
        desired_direction = Vector3()
    var jumped: bool = default_entity_movement(delta, desired_direction, ground_accel, speed * direction_alignment * (1.0 if state != DEFENSE else defense_speed_multiplier), will_jump, true, false)

    if jumped:
        will_jump = false

    if not jumped and is_on_floor() and %WallRayCast3D.is_colliding() and (state == DEFENSE or velocity.length() > 2.0):
        will_jump = true

    const look_accel: float = 4.0
    look_at_direction(desired_direction)
    rotation_pivot.rotation.y = lerp_angle(rotation_pivot.rotation.y, desired_angle, delta * look_accel)
    model.look_target = lerp(model.look_target, look_target, delta * look_accel)
    interact_ray.global_position = head.global_position
    interact_ray.target_position = interact_ray.to_local(model.look_target).normalized() * interact_distance

    var anim_speed: float = clamp(0.0, velocity.length() / speed, 1.0)
    anim["parameters/walk/blend_amount"] = lerp(anim["parameters/walk/blend_amount"], anim_speed * (1.0 if state != DEFENSE else 1.5), delta * 8.0)

    if %DirectDamageTimer.time_left > 0.2:
        anim["parameters/hurt/blend_amount"] = lerp(anim["parameters/hurt/blend_amount"], 1.0, delta * 18.0)
    else:
        anim["parameters/hurt/blend_amount"] = lerp(anim["parameters/hurt/blend_amount"], 0.0, delta * 4.0)


func attack() -> void :
    if not attack_timer.is_stopped() or state != DEFENSE or dead or disabled:
        return
    if is_instance_valid(attack_target) and not attack_target.dead:
        melee_attack()


func get_interact_data() -> Dictionary:
    var data: Dictionary = {}

    data.interact_begin = interact_ray.global_position
    data.interact_end = interact_ray.to_global(interact_ray.target_position)
    data.interact_normal = interact_ray.get_collision_normal()
    data.interact_end_adjacent = interact_ray.get_collision_point() + interact_ray.get_collision_normal() * 0.5

    interact_ray.force_raycast_update()
    if interact_ray.is_colliding():
        data.interact_end = interact_ray.get_collision_point()

        var collider: Object = interact_ray.get_collider()
        if not (collider.owner is Ball or collider.owner is Heart or collider.owner is Entity):
            var target_position: Vector3 = (interact_ray.get_collision_point() - interact_ray.get_collision_normal() * 0.5).floor()
            if is_session_position_loaded(target_position) and Ref.world.is_block_solid_at(target_position):
                data.target_position = target_position
                data.target_position_adjacent = data.target_position + interact_ray.get_collision_normal()

    return data


func ascend() -> void :
    var blocks: int = randi_range(1, 4)
    for i in range(blocks):
        look_target = global_position - Vector3(0, 1, 0)
        await get_tree().create_timer(0.2, false).timeout

        will_jump = true
        await get_tree().create_timer(0.2, false).timeout

        place_block()

        await get_tree().create_timer(0.3, false).timeout
    look_target = global_position - rotation_pivot.transform.basis.z.normalized() + Vector3(0, 1.1, 0)


func build_ahead() -> void :
    var blocks: int = randi_range(1, 4)
    for i in range(blocks):
        look_target = global_position - rotation_pivot.transform.basis.z.normalized() * randf_range(1.0, look_ahead_distance)
        await get_tree().create_timer(0.5, false).timeout

        place_block()

        await get_tree().create_timer(0.3, false).timeout
    look_target = global_position - rotation_pivot.transform.basis.z.normalized() + Vector3(0, 1.1, 0)


func melee_attack() -> void :
    attack_timer.start(melee_delay)

    if attack_target.global_position.distance_to(global_position) > 3.0:
        return

    anim["parameters/interact/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
    await model.fired
    %WhiffPlayer3D.play()

    if not is_instance_valid(attack_shape) or not attack_shape.is_inside_tree() or not is_inside_tree() or dead or disabled or not is_instance_valid(attack_target) or attack_target.dead or attack_target.disabled:
        return

    attack_shape.force_shapecast_update()
    var collided: bool = false
    for i in range(attack_shape.get_collision_count()):
        collided = collided or _collider_matches_attack_target(attack_shape.get_collider(i))
        if collided:
            break

    if collided:
        %Attack.attack(attack_target, attack_target.global_position, 16)


func _collider_matches_attack_target(collider) -> bool:
    if not is_instance_valid(collider) or not is_instance_valid(attack_target):
        return false
    if collider == attack_target:
        return true
    if collider is Area3D:
        if collider.has_meta("coop_proxy_owner"):
            return collider.get_meta("coop_proxy_owner") == attack_target
        if is_instance_valid(collider.owner):
            return collider.owner == attack_target
        if is_instance_valid(collider.get_parent()):
            return collider.get_parent() == attack_target
    return false


func place_block() -> void :
    var data: Dictionary = get_interact_data()
    if not is_interacting() and is_instance_valid(held_item):
        var can_interact_using_item: bool = is_instance_valid(held_item) and held_item.can_interact(data)
        if can_interact_using_item:
            anim["parameters/interact/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
            await model.fired
        can_interact_using_item = is_instance_valid(held_item) and held_item.can_interact(data)

        var _success: bool = can_interact_using_item and await held_item.interact(true, data)
        if is_interacting():
            held_item.interact_end()


func random_walk() -> void :
    var walk_time: float = randf_range(1.0, 2.0)
    desired_direction = Vector3(randf() - 0.5, 0, randf() - 0.5).normalized()
    look_target = global_position + desired_direction * speed * walk_time
    await get_tree().create_timer(walk_time, false).timeout
    desired_direction = Vector3()
    look_target = global_position - rotation_pivot.transform.basis.z.normalized() + Vector3(0, 1.1, 0)


func initialize_state() -> void :
    if state == DEFENSE:
        hold_item(WEAPON_INDEX)
    else:
        hold_item(BUILD_INDEX)


func look_at_direction(direction: Vector3) -> void :
    if dead:
        return

    var dir: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
    if dir.is_zero_approx():
        return

    desired_angle = PI + atan2(dir.x, dir.z)


func preserve_save(file: SaveFile, uuid: String) -> void :
    super.preserve_save(file, uuid)
    file.set_data("node/%s/desired_angle" % uuid, desired_angle)


func preserve_load(file: SaveFile, uuid: String) -> void :
    super.preserve_load(file, uuid)
    desired_angle = file.get_data("node/%s/desired_angle" % uuid, 0)
    %RotationPivot.rotation.y = desired_angle
