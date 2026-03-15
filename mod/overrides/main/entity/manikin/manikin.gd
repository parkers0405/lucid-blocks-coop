class_name Manikin extends Entity

@export var wary_wander_min: float = 4.0
@export var wary_wander_max: float = 7.0
@export var chase_wander_min: float = 0.2
@export var chase_wander_max: float = 0.4
@export var wary_range: float = 2.0
@export var chase_range: float = 2.0
@export var wander_forget_chance: float = 0.25
@export var nonchase_speed_multiplier: float = 0.5
@export var idle_hostility_rate: float = 0.005
@export var wary_hostility_rate: float = 0.08
@export var jump_attack_chance: float = 0.4
@export var crucify_chance: float = 0.5
@export var weapons: Array[Item]
@export var rare_weapons: Array[Item]
@export var weapon_chance: float = 0.15
@export var rare_weapon_chance: float = 0.2
@export var shoot_distance: float = 3.0
@export var melee_delay: float = 0.85
@export var ball_delay: float = 1.5
@export var rod_delay: float = 3.0
@export var spacer_radius: float = 4.0
@export var spacer_radius_run: float = 4.0
@export var direction_punish: float = 0.4

@onready var anim: AnimationTree = %ManikinModel.get_node("%AnimationTree")

enum {IDLE, CHASE, WARY, CRUCIFY}

var player: Player
var attack_target: Entity
var state: int = IDLE
var hostility: float = 0.0
var will_jump: bool = false
static var friend_hostility: float = 0.0

var interest_place: Vector3
var desired_direction: Vector3
var desired_angle: float = 0.0
var attack_speed_modifier: float = 1.0
var direction_to_player: Vector3


func _ready() -> void :
    hand = %ManikinModel.get_node("%Hand")
    head = %ManikinModel.get_node("%Head")
    %ManikinModel.fired.connect(_on_fired)

    %DetectionArea3D.body_entered.connect(_on_player_entered)
    %DetectionArea3D.body_exited.connect(_on_player_exited)

    %AttackArea3D.body_entered.connect(_on_attack_entered)
    %AttackArea3D.body_exited.connect(_on_attack_exited)

    %AttackTimer.timeout.connect(_on_attack_timeout)

    on_attacked.connect(_on_attacked)

    %WaryWander.timeout.connect(_on_wary_wander_timeout)
    %ChaseWander.timeout.connect(_on_chase_wander_timeout)

    idle_hostility_rate *= randf_range(0.5, 1.0)
    wary_hostility_rate *= randf_range(0.5, 1.0)

    if Ref.world.current_dimension == LucidBlocksWorld.Dimension.CHALLENGE:
        wary_hostility_rate *= 3.0

    speed *= randf_range(0.9, 1.2)

    anim["parameters/walk/blend_amount"] = 0.0
    anim["parameters/crucify/blend_amount"] = randf_range(-0.1, 0.3)
    anim.advance(1.0)

    desired_angle = randf_range(0, 2 * PI)
    %RotationPivot.rotation.y = desired_angle

    if randf() < crucify_chance:
        state = CRUCIFY

    super._ready()

    if randf() < weapon_chance and not Ref.world.current_dimension == LucidBlocksWorld.Dimension.CHALLENGE:
        var weapon: Item = weapons.pick_random() if randf() > rare_weapon_chance else rare_weapons.pick_random()
        var weapon_state: ItemState = ItemState.new()
        weapon_state.initialize(weapon)
        if weapon is Tool or weapon is Wand:
            weapon_state.durability = randi_range(1, weapon.max_durability / 2)
        held_item_inventory.set_item(0, weapon_state)


func get_random_flat_vector() -> Vector3:
    return Vector3(randf() - 0.5, 0.0, randf() - 0.5).normalized()


func _has_session_player_target() -> bool:
    return _use_server_session_targeting() and is_session_target_within(process_distance)


func _has_active_target() -> bool:
    return (is_instance_valid(player) and not player.dead) or _has_session_player_target()


func _get_target_position() -> Vector3:
    return get_session_target_position(player.global_position if is_instance_valid(player) else global_position)


func _get_target_head_position() -> Vector3:
    var fallback_head: Vector3 = global_position + Vector3(0, 1.45, 0)
    if is_instance_valid(player) and is_instance_valid(player.head):
        fallback_head = player.head.global_position
    return get_session_target_head_position(fallback_head)


func _on_fired() -> void :
    if not is_spacer() or dead or disabled or state != CHASE:
        return
    if held_item.can_interact({}):
        held_item.interact(false, {})


func _on_attacked(attacker: Entity) -> void :
    if is_instance_valid(attacker) and attacker is Player:
        hostility += 1.0
        friend_hostility += 0.25
    elif attacker == null and _has_session_player_target():
        hostility += 1.0
        friend_hostility += 0.25

    if randf() < jump_attack_chance:
        will_jump = true


func _on_chase_wander_timeout() -> void :
    if state == CHASE:
        if _has_active_target():
            interest_place = _get_target_position() + get_random_flat_vector() * chase_range
        %ChaseWander.start(randf_range(chase_wander_min, chase_wander_max))


func _on_wary_wander_timeout() -> void :
    if state == WARY:
        if _has_active_target():
            interest_place = _get_target_position() + get_random_flat_vector() * wary_range
        else:
            interest_place = interest_place + get_random_flat_vector() * wary_range
            if randf() < wander_forget_chance:
                switch_state(IDLE)
                return
        %WaryWander.start(randf_range(wary_wander_min, wary_wander_max))


func _on_attack_timeout() -> void :
    if dead or state != CHASE:
        return
    attack()


func _on_attack_entered(body: PhysicsBody3D) -> void :
    if dead or state != CHASE:
        return

    attack_target = body as Entity

    attack()


func _on_attack_exited(_body: PhysicsBody3D) -> void :
    if dead or not is_inside_tree() or not has_node("%RotationPivot/AttackArea3D") or not %RotationPivot / AttackArea3D.owner:
        return

    attack_target = null


func _on_player_entered(body: PhysicsBody3D) -> void :
    if dead:
        return
    player = body as Player
    interest_place = _get_target_position() + get_random_flat_vector() * wary_range
    switch_state(WARY)


func _on_player_exited(_body: PhysicsBody3D) -> void :
    if dead or not is_inside_tree() or not has_node("%DetectionArea3D") or not %DetectionArea3D.owner:
        return

    interest_place = _get_target_position()
    player = null

    if state == CHASE:
        switch_state(WARY)
    else:
        switch_state(IDLE)


func _physics_process(delta: float) -> void :
    if disabled or not is_session_position_loaded(global_position):
        return
    super._physics_process(delta)
    if is_future_position_loaded(delta):
        move_and_slide()

    if not is_instance_valid(player) and _has_session_player_target() and state != CHASE:
        interest_place = _get_target_position() + get_random_flat_vector() * wary_range
        switch_state(WARY)

    if state == CHASE:
        chase_process(delta)
    if state == WARY:
        wary_process(delta)
    if state == IDLE:
        hostility = lerp(hostility, 0.0, delta * idle_hostility_rate)
        %ManikinModel.look_ratio = lerp(%ManikinModel.look_ratio, 0.0, clamp(delta * 4.0, 0.0, 1.0))

    if dead:
        desired_direction = Vector3()

    friend_hostility = lerp(friend_hostility, 0.0, delta * 0.1)
    attack_speed_modifier = lerp(attack_speed_modifier, 1.0, clamp(delta * 6.0, 0.0, 1.0))

    var target_speed: float = attack_speed_modifier * speed * speed_modifier * (nonchase_speed_multiplier if state != CHASE else 1.0)
    var direction_alignment: float = lerp(direction_punish, 1.0, (desired_direction.dot(%RotationPivot.basis.z) + 1.0) / 2.0)

    var jumped: bool = default_entity_movement(delta, desired_direction, ground_accel, target_speed * direction_alignment, will_jump, true, false)

    if jumped:
        will_jump = false

    var anim_speed: float = clamp(0.0, velocity.length() / speed, 1.0)
    anim["parameters/walk/blend_amount"] = lerp(anim["parameters/walk/blend_amount"], anim_speed, delta * 8.0)

    if %DirectDamageTimer.time_left > 0.2:
        anim["parameters/hurt/blend_amount"] = lerp(anim["parameters/hurt/blend_amount"], 1.0, delta * 18.0)
    else:
        anim["parameters/hurt/blend_amount"] = lerp(anim["parameters/hurt/blend_amount"], 0.0, delta * 4.0)

    %RotationPivot.rotation.y = lerp_angle(%RotationPivot.rotation.y, desired_angle, delta * 4.0)


func chase_process(delta: float) -> void :
    if not _has_active_target():
        switch_state(IDLE)
        return

    hostility = 1.0

    var target_position: Vector3 = _get_target_position()
    if global_position.distance_to(interest_place) < 0.1 or %WallRayCast3D.is_colliding():
        interest_place = target_position + get_random_flat_vector() * chase_range

    %ManikinModel.look_target = _get_target_head_position()
    %ManikinModel.look_ratio = lerp(%ManikinModel.look_ratio, 1.0, clamp(delta * 6.0, 0.0, 1.0))

    if is_on_floor() and %JumpRayCast3D.is_colliding():
        will_jump = true

    if is_spacer():
        if target_position.distance_to(global_position) < spacer_radius_run:
            interest_place = target_position + target_position.direction_to(global_position) * spacer_radius
        elif target_position.distance_to(global_position) < spacer_radius:
            interest_place = global_position

    if is_spacer():
        attack()

    if is_spacer():
        direction_to_player = lerp(direction_to_player, global_position.direction_to(target_position), delta * 2.0)
        look_at_desired_direction(direction_to_player)
    else:
        look_at_desired_direction(desired_direction)

    desired_direction = interest_place - global_position
    desired_direction.y = 0
    desired_direction = desired_direction.normalized()


func wary_process(delta: float) -> void :
    if _has_active_target():
        %ManikinModel.look_target = _get_target_head_position()
    %ManikinModel.look_ratio = lerp(%ManikinModel.look_ratio, 1.0, clamp(delta * 4.0, 0.0, 1.0))
    if (interest_place - global_position).length() > 0.25:
        desired_direction = (interest_place - global_position).normalized()
        if desired_direction.length() > 0.0:
            look_at_desired_direction(desired_direction)
            if is_on_floor() and %JumpRayCast3D.is_colliding() and not %WallRayCast3D.is_colliding():
                will_jump = true
    else:
        desired_direction = Vector3()

    hostility = lerp(hostility, 1.0, delta * wary_hostility_rate)
    if friend_hostility + hostility > 0.75 and _has_active_target():
        interest_place = _get_target_position()
        desired_direction = interest_place - global_position
        desired_direction.y = 0
        desired_direction = desired_direction.normalized()
        switch_state(CHASE)


func look_at_desired_direction(direction: Vector3) -> void :
    if dead:
        return

    var dir: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
    if dir.is_zero_approx():
        return

    desired_angle = atan2(dir.x, dir.z)


func switch_state(new_state: int) -> void :
    state = new_state
    if not is_inside_tree() or dead:
        return

    if new_state == IDLE:
        desired_direction = Vector3()
    if new_state == WARY and has_node("%WaryWander") and %WaryWander.is_inside_tree():
        %WaryWander.start(randf_range(wary_wander_min, wary_wander_max))
    if new_state == CHASE and has_node("%ChaseWander") and %ChaseWander.is_inside_tree():
        direction_to_player = desired_direction
        %ChaseWander.start(randf_range(chase_wander_min, chase_wander_max))

        if not disabled:
            attack()


func attack() -> void :
    if not %AttackTimer.is_stopped() or state != CHASE or dead or disabled or not is_inside_tree():
        return

    if is_spacer() and _get_target_position().distance_to(global_position) > shoot_distance:
        if is_facing_player():
            shoot_ball()
    elif attack_target != null and not attack_target.dead:
        melee_attack()


func melee_attack() -> void :
    %WhiffPlayer3D.play()
    anim["parameters/attack/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
    attack_speed_modifier = 0.05
    %Attack.attack(attack_target, attack_target.global_position)
    %AttackTimer.start(melee_delay)


func shoot_ball() -> void :
    %WindupPlayer.play()
    anim["parameters/shoot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
    attack_speed_modifier = 0.14
    %AttackTimer.start(ball_delay if held_item is HeldBallThrower else rod_delay)


func preserve_save(file: SaveFile, uuid: String) -> void :
    super.preserve_save(file, uuid)
    file.set_data("node/%s/desired_angle" % uuid, desired_angle)


func preserve_load(file: SaveFile, uuid: String) -> void :
    super.preserve_load(file, uuid)
    desired_angle = file.get_data("node/%s/desired_angle" % uuid, 0)
    %RotationPivot.rotation.y = desired_angle


func get_look_direction() -> Vector3:
    return %RotationPivot.get_global_transform().basis.z if not _has_active_target() else hand.global_position.direction_to(_get_target_head_position() + Vector3(0, 0.1, 0))


func is_spacer() -> bool:
    return held_item != null and (held_item is HeldBallThrower or held_item is HeldRodThrower)


func is_facing_player() -> bool:
    return %RotationPivot.get_global_transform().basis.z.dot(global_position.direction_to(_get_target_position())) > 0.2
