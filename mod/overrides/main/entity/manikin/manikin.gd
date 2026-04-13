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
@export var spacer_attack_max_distance_padding: float = 0.75

@onready var anim: AnimationTree = %ManikinModel.get_node("%AnimationTree")

enum {IDLE, CHASE, WARY, CRUCIFY}

var player
var attack_target
var state: int = IDLE
var hostility: float = 0.0
var will_jump: bool = false
static var friend_hostility: float = 0.0

var interest_place: Vector3
var desired_direction: Vector3
var desired_angle: float = 0.0
var attack_speed_modifier: float = 1.0
var direction_to_player: Vector3
var forced_session_target = null


func _debug_state_name(value: int) -> String:
    match value:
        IDLE:
            return "IDLE"
        CHASE:
            return "CHASE"
        WARY:
            return "WARY"
        CRUCIFY:
            return "CRUCIFY"
    return str(value)


func _debug_target_label(target) -> String:
    if not is_instance_valid(target):
        return "<null>"
    var label := "%s:%s" % [target.name, target.get_class()]
    if Ref.coop_manager != null and Ref.coop_manager.is_remote_player_proxy(target):
        label += ":remote_peer=%s" % Ref.coop_manager.get_remote_player_proxy_peer_id(target)
    if "disabled" in target:
        label += ":disabled=%s" % str(bool(target.disabled))
    if "dead" in target:
        label += ":dead=%s" % str(bool(target.dead))
    return label


func _debug_log(message: String) -> void:
    if not _use_session_targeting():
        return
    print("[lucid-blocks-coop][manikin-debug] ", message)


func _ready() -> void:
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
    distance_process_check()

    if randf() < weapon_chance and Ref.world.current_dimension != LucidBlocksWorld.Dimension.CHALLENGE:
        var weapon: Item = weapons.pick_random() if randf() > rare_weapon_chance else rare_weapons.pick_random()
        var weapon_state: ItemState = ItemState.new()
        weapon_state.initialize(weapon)
        if weapon is Tool or weapon is Wand:
            weapon_state.durability = randi_range(1, weapon.max_durability / 2)
        held_item_inventory.set_item(0, weapon_state)


func _use_session_targeting() -> bool:
    return multiplayer.is_server() and Ref.coop_manager != null and Ref.coop_manager.has_connected_remote_peers()


func _is_session_position_loaded(world_position: Vector3) -> bool:
    if Ref.world.is_position_loaded(world_position):
        return true
    return _can_use_session_load_proxy() and Ref.coop_manager.is_position_near_same_instance_player(world_position, process_distance)


func is_future_position_loaded(delta: float) -> bool:
    var future_position: Vector3 = global_position + velocity * delta
    if Ref.world.is_position_loaded(future_position):
        return true
    return _can_use_session_load_proxy() and Ref.coop_manager.is_position_near_same_instance_player(future_position, process_distance)


func distance_process_check() -> void:
    var distance: float = Ref.player.global_position.distance_to(global_position)
    var near_session_player: bool = false
    if _can_use_session_load_proxy():
        var session_distance: float = Ref.coop_manager.get_nearest_session_player_distance(global_position, distance)
        near_session_player = session_distance < distance
        distance = session_distance

    if has_node("%VisibleOnScreenEnabler3D"):
        if _use_session_targeting():
            %VisibleOnScreenEnabler3D.enable_node_path = ""
            %VisibleOnScreenEnabler3D.process_mode = Node.PROCESS_MODE_DISABLED
        else:
            %VisibleOnScreenEnabler3D.enable_node_path = "" if near_session_player or not disabled_by_visibility else ".."
            %VisibleOnScreenEnabler3D.process_mode = Node.PROCESS_MODE_INHERIT
    if near_session_player:
        disabled = false

    if distance >= process_distance:
        set_physics_process(false)
        set_process(false)
    elif near_session_player or not disabled_by_visibility or %VisibleOnScreenEnabler3D.is_on_screen():
        set_physics_process(true)
        set_process(true)


func _is_session_player_entity(entity) -> bool:
    return is_instance_valid(entity) and (entity == Ref.player or (_use_session_targeting() and Ref.coop_manager.is_remote_player_proxy(entity)))


func _has_session_player_target() -> bool:
    return _use_session_targeting() and Ref.coop_manager.is_position_near_same_instance_player(global_position, process_distance)


func _has_active_target() -> bool:
    return _is_target_active(player) or _has_session_player_target()


func _is_target_active(target) -> bool:
    return is_instance_valid(target) and not target.dead and not target.disabled


func _get_forced_session_target():
    if not _is_target_active(forced_session_target) or not _is_session_player_entity(forced_session_target):
        forced_session_target = null
        return null
    return forced_session_target


func _get_target_position() -> Vector3:
    var preferred_target = _get_session_target_player()
    var fallback: Vector3 = preferred_target.global_position if is_instance_valid(preferred_target) else global_position
    if not _use_session_targeting():
        return fallback
    return Ref.coop_manager.get_nearest_session_player_position(global_position, fallback)


func _get_target_head_position() -> Vector3:
    var fallback: Vector3 = global_position + Vector3(0, 1.45, 0)
    var preferred_target = _get_session_target_player()
    if is_instance_valid(preferred_target) and is_instance_valid(preferred_target.head):
        fallback = preferred_target.head.global_position
    if not _use_session_targeting():
        return fallback
    return Ref.coop_manager.get_nearest_session_player_head_position(global_position, fallback)


func _get_session_target_player():
    var preferred_target = _get_forced_session_target()
    if is_instance_valid(preferred_target):
        return preferred_target

    var fallback = player if is_instance_valid(player) else Ref.player
    if not _use_session_targeting():
        return fallback
    return Ref.coop_manager.get_nearest_session_player_entity(global_position, fallback)


func get_coop_locked_target_peer_id() -> int:
    var locked_target = _get_forced_session_target()
    if not _use_session_targeting() or not is_instance_valid(locked_target):
        return -1
    if not Ref.coop_manager.is_remote_player_proxy(locked_target):
        return -1
    return Ref.coop_manager.get_remote_player_proxy_peer_id(locked_target)


func _force_session_runtime_active() -> void:
    if not _use_session_targeting():
        return

    disabled = false
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_process(true)
    set_physics_process(true)

    if has_node("%VisibleOnScreenEnabler3D"):
        %VisibleOnScreenEnabler3D.enable_node_path = ""
        %VisibleOnScreenEnabler3D.process_mode = Node.PROCESS_MODE_DISABLED

    if anim != null:
        anim.process_mode = Node.PROCESS_MODE_ALWAYS
        anim.active = true
    var animation_player := %ManikinModel.get_node_or_null("AnimationPlayer") as AnimationPlayer
    if animation_player != null:
        animation_player.process_mode = Node.PROCESS_MODE_ALWAYS


func _get_detection_radius() -> float:
    var detection_shape := %DetectionArea3D.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if detection_shape != null and detection_shape.shape is SphereShape3D:
        return float((detection_shape.shape as SphereShape3D).radius)
    return 8.0


func _get_max_spacer_attack_distance() -> float:
    return maxf(shoot_distance, _get_detection_radius() + spacer_attack_max_distance_padding)


func _get_melee_attack_max_distance() -> float:
    var collision_shape := %AttackArea3D.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if collision_shape != null:
        if collision_shape.shape is CylinderShape3D:
            var cylinder := collision_shape.shape as CylinderShape3D
            return maxf(1.0, float(cylinder.radius) + 1.0)
        if collision_shape.shape is SphereShape3D:
            var sphere := collision_shape.shape as SphereShape3D
            return maxf(1.0, float(sphere.radius) + 0.75)
        if collision_shape.shape is BoxShape3D:
            var box := collision_shape.shape as BoxShape3D
            return maxf(1.0, Vector2(box.size.x, box.size.z).length() * 0.5 + 0.75)
    return 1.5


func _can_melee_attack_target() -> bool:
    if not is_instance_valid(attack_target) or attack_target.dead:
        return false
    if not _is_target_active(attack_target):
        return false

    if %AttackArea3D.has_overlapping_bodies() and attack_target in %AttackArea3D.get_overlapping_bodies():
        return true

    var target_distance: float = global_position.distance_to(attack_target.global_position)
    return target_distance <= _get_melee_attack_max_distance()


func _promote_session_attacker(attacker) -> void:
    var session_target = attacker
    if not _is_session_player_entity(session_target) and is_instance_valid(session_target) and session_target is Player:
        session_target = attacker
    if not _is_session_player_entity(session_target):
        session_target = _get_session_target_player()
    if not is_instance_valid(session_target):
        return

    player = session_target
    attack_target = session_target
    forced_session_target = session_target
    hostility = maxf(hostility, 1.0)
    friend_hostility = maxf(friend_hostility, 0.25)
    interest_place = _get_target_position()
    desired_direction = interest_place - global_position
    desired_direction.y = 0.0
    if desired_direction.length_squared() > 0.0001:
        desired_direction = desired_direction.normalized()
    _force_session_runtime_active()
    if state != CHASE:
        switch_state(CHASE)
    _debug_log("promote attacker=%s forced=%s player=%s" % [
        _debug_target_label(attacker),
        _debug_target_label(forced_session_target),
        _debug_target_label(player),
    ])
    attack()


func get_random_flat_vector() -> Vector3:
    return Vector3(randf() - 0.5, 0.0, randf() - 0.5).normalized()


func _on_fired() -> void:
    if not is_spacer() or dead or disabled or state != CHASE:
        return
    if held_item.can_interact({}):
        held_item.interact(false, {})


func _on_attacked(attacker) -> void:
    if _is_session_player_entity(attacker) or (is_instance_valid(attacker) and attacker is Player):
        _promote_session_attacker(attacker)

    if randf() < jump_attack_chance:
        will_jump = true


func _on_chase_wander_timeout() -> void:
    if state == CHASE:
        if _has_active_target():
            interest_place = _get_target_position() + get_random_flat_vector() * chase_range
        %ChaseWander.start(randf_range(chase_wander_min, chase_wander_max))


func _on_wary_wander_timeout() -> void:
    if state == WARY:
        if _has_active_target():
            interest_place = _get_target_position() + get_random_flat_vector() * wary_range
        else:
            interest_place += get_random_flat_vector() * wary_range
            if randf() < wander_forget_chance:
                switch_state(IDLE)
                return
        %WaryWander.start(randf_range(wary_wander_min, wary_wander_max))


func _on_attack_timeout() -> void:
    if dead or state != CHASE:
        return
    attack()


func _on_attack_entered(body: PhysicsBody3D) -> void:
    if dead or state != CHASE:
        return
    var locked_target = _get_forced_session_target()
    if is_instance_valid(locked_target) and body != locked_target:
        _debug_log("ignore attack-enter body=%s locked=%s" % [
            _debug_target_label(body),
            _debug_target_label(locked_target),
        ])
        return

    attack_target = body as Entity
    _debug_log("attack-enter target=%s" % _debug_target_label(attack_target))
    attack()


func _on_attack_exited(body: PhysicsBody3D) -> void:
    if dead or not is_inside_tree() or not has_node("%RotationPivot/AttackArea3D") or not %RotationPivot / AttackArea3D.owner:
        return
    if body == attack_target:
        var locked_target = _get_forced_session_target()
        attack_target = locked_target if is_instance_valid(locked_target) else null


func _on_player_entered(body: PhysicsBody3D) -> void:
    if dead:
        return
    if not _is_session_player_entity(body):
        return
    var locked_target = _get_forced_session_target()
    if is_instance_valid(locked_target) and body != locked_target:
        _debug_log("ignore detect-enter body=%s locked=%s" % [
            _debug_target_label(body),
            _debug_target_label(locked_target),
        ])
        return
    _force_session_runtime_active()
    player = body
    attack_target = body
    interest_place = _get_target_position() + get_random_flat_vector() * wary_range
    _debug_log("detect-enter player=%s attack_target=%s" % [
        _debug_target_label(player),
        _debug_target_label(attack_target),
    ])
    switch_state(WARY)


func _on_player_exited(body: PhysicsBody3D) -> void:
    if dead or not is_inside_tree() or not has_node("%DetectionArea3D") or not %DetectionArea3D.owner:
        return
    if body != player:
        return
    if body == _get_forced_session_target():
        return

    interest_place = _get_target_position()
    player = null

    if state == CHASE:
        switch_state(WARY)
    else:
        switch_state(IDLE)


func _physics_process(delta: float) -> void:
    if disabled or not _is_session_position_loaded(global_position):
        return
    super._physics_process(delta)
    if is_future_position_loaded(delta):
        move_and_slide()

    if _use_session_targeting() and _has_session_player_target():
        _force_session_runtime_active()
        var locked_target = _get_forced_session_target()
        var session_target = _get_session_target_player()
        if is_instance_valid(session_target):
            player = session_target
            if is_instance_valid(locked_target):
                attack_target = locked_target
                player = locked_target
            elif state == CHASE or not is_instance_valid(attack_target) or _is_session_player_entity(attack_target):
                attack_target = session_target
            if state != CHASE and hostility + friend_hostility >= 0.75:
                _promote_session_attacker(session_target)
        if state != CHASE and not is_instance_valid(player):
            player = session_target
        if state != CHASE:
            interest_place = _get_target_position() + get_random_flat_vector() * wary_range
            switch_state(WARY)
    elif state == CHASE and not is_instance_valid(attack_target):
        var attack_target_candidate = _get_session_target_player()
        if is_instance_valid(attack_target_candidate):
            player = attack_target_candidate
            attack_target = attack_target_candidate

    if state == CHASE:
        chase_process(delta)
    if state == WARY:
        wary_process(delta)
    if state == IDLE:
        hostility = lerp(hostility, 0.0, delta * idle_hostility_rate)
        %ManikinModel.look_ratio = lerp(%ManikinModel.look_ratio, 0.0, clampf(delta * 4.0, 0.0, 1.0))

    if dead:
        desired_direction = Vector3.ZERO

    friend_hostility = lerp(friend_hostility, 0.0, delta * 0.1)
    attack_speed_modifier = lerp(attack_speed_modifier, 1.0, clampf(delta * 6.0, 0.0, 1.0))

    var target_speed: float = attack_speed_modifier * speed * speed_modifier * (nonchase_speed_multiplier if state != CHASE else 1.0)
    var direction_alignment: float = lerp(direction_punish, 1.0, (desired_direction.dot(%RotationPivot.basis.z) + 1.0) / 2.0)

    var jumped: bool = default_entity_movement(delta, desired_direction, ground_accel, target_speed * direction_alignment, will_jump, true, false)

    if jumped:
        will_jump = false

    var anim_speed: float = clampf(velocity.length() / speed, 0.0, 1.0)
    anim["parameters/walk/blend_amount"] = lerp(anim["parameters/walk/blend_amount"], anim_speed, delta * 8.0)

    if %DirectDamageTimer.time_left > 0.2:
        anim["parameters/hurt/blend_amount"] = lerp(anim["parameters/hurt/blend_amount"], 1.0, delta * 18.0)
    else:
        anim["parameters/hurt/blend_amount"] = lerp(anim["parameters/hurt/blend_amount"], 0.0, delta * 4.0)

    %RotationPivot.rotation.y = lerp_angle(%RotationPivot.rotation.y, desired_angle, delta * 4.0)


func chase_process(delta: float) -> void:
    if not _has_active_target():
        switch_state(IDLE)
        return

    hostility = 1.0

    var target_position: Vector3 = _get_target_position()
    if global_position.distance_to(interest_place) < 0.1 or %WallRayCast3D.is_colliding():
        interest_place = target_position + get_random_flat_vector() * chase_range

    %ManikinModel.look_target = _get_target_head_position()
    %ManikinModel.look_ratio = lerp(%ManikinModel.look_ratio, 1.0, clampf(delta * 6.0, 0.0, 1.0))

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
    desired_direction.y = 0.0
    desired_direction = desired_direction.normalized()


func wary_process(delta: float) -> void:
    if _has_active_target():
        %ManikinModel.look_target = _get_target_head_position()
    %ManikinModel.look_ratio = lerp(%ManikinModel.look_ratio, 1.0, clampf(delta * 4.0, 0.0, 1.0))
    if (interest_place - global_position).length() > 0.25:
        desired_direction = (interest_place - global_position).normalized()
        if desired_direction.length() > 0.0:
            look_at_desired_direction(desired_direction)
            if is_on_floor() and %JumpRayCast3D.is_colliding() and not %WallRayCast3D.is_colliding():
                will_jump = true
    else:
        desired_direction = Vector3.ZERO

    hostility = lerp(hostility, 1.0, delta * wary_hostility_rate)
    if friend_hostility + hostility > 0.75 and _has_active_target():
        interest_place = _get_target_position()
        desired_direction = interest_place - global_position
        desired_direction.y = 0.0
        desired_direction = desired_direction.normalized()
        switch_state(CHASE)


func look_at_desired_direction(direction: Vector3) -> void:
    if dead:
        return

    var dir: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
    if dir.is_zero_approx():
        return

    desired_angle = atan2(dir.x, dir.z)


func switch_state(new_state: int) -> void:
    var previous_state: int = state
    state = new_state
    if not is_inside_tree() or dead:
        return
    if previous_state != new_state:
        _debug_log("switch %s -> %s player=%s attack_target=%s forced=%s" % [
            _debug_state_name(previous_state),
            _debug_state_name(new_state),
            _debug_target_label(player),
            _debug_target_label(attack_target),
            _debug_target_label(forced_session_target),
        ])

    if new_state == IDLE:
        desired_direction = Vector3.ZERO
    if new_state == WARY and has_node("%WaryWander") and %WaryWander.is_inside_tree():
        %WaryWander.start(randf_range(wary_wander_min, wary_wander_max))
    if new_state == CHASE and has_node("%ChaseWander") and %ChaseWander.is_inside_tree():
        direction_to_player = desired_direction
        %ChaseWander.start(randf_range(chase_wander_min, chase_wander_max))

        if not disabled:
            attack()


func attack() -> void:
    if not %AttackTimer.is_stopped() or state != CHASE or dead or disabled or not is_inside_tree():
        return

    var target_distance: float = _get_target_position().distance_to(global_position)
    _debug_log("attack spacer=%s facing=%s dist=%.2f player=%s attack_target=%s forced=%s held=%s" % [
        str(is_spacer()),
        str(is_facing_player()),
        target_distance,
        _debug_target_label(player),
        _debug_target_label(attack_target),
        _debug_target_label(forced_session_target),
        held_item.get_class() if is_instance_valid(held_item) else "<none>",
    ])
    if is_spacer() and target_distance > _get_max_spacer_attack_distance():
        return
    if is_spacer() and target_distance > shoot_distance:
        if is_facing_player():
            shoot_ball()
    elif _can_melee_attack_target():
        melee_attack()


func melee_attack() -> void:
    if not _can_melee_attack_target():
        return
    %WhiffPlayer3D.play()
    anim["parameters/attack/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
    attack_speed_modifier = 0.05
    %Attack.attack(attack_target, attack_target.global_position)
    %AttackTimer.start(melee_delay)


func shoot_ball() -> void:
    _debug_log("shoot player=%s head=%s look_dir=%s" % [
        _debug_target_label(player),
        str(_get_target_head_position()),
        str(get_look_direction()),
    ])
    %WindupPlayer.play()
    anim["parameters/shoot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
    attack_speed_modifier = 0.14
    %AttackTimer.start(ball_delay if held_item is HeldBallThrower else rod_delay)


func preserve_save(file: SaveFile, uuid: String) -> void:
    super.preserve_save(file, uuid)
    file.set_data("node/%s/desired_angle" % uuid, desired_angle)


func preserve_load(file: SaveFile, uuid: String) -> void:
    super.preserve_load(file, uuid)
    desired_angle = file.get_data("node/%s/desired_angle" % uuid, 0)
    %RotationPivot.rotation.y = desired_angle


func get_look_direction() -> Vector3:
    if not is_inside_tree() or not %RotationPivot.is_inside_tree():
        return Vector3.FORWARD
    if not _has_active_target() or not is_instance_valid(hand) or not hand.is_inside_tree():
        return %RotationPivot.get_global_transform().basis.z
    return hand.global_position.direction_to(_get_target_head_position() + Vector3(0, 0.1, 0))


func is_spacer() -> bool:
    return held_item != null and (held_item is HeldBallThrower or held_item is HeldRodThrower)


func is_facing_player() -> bool:
    if not is_inside_tree() or not %RotationPivot.is_inside_tree():
        return false
    return %RotationPivot.get_global_transform().basis.z.dot(global_position.direction_to(_get_target_position())) > 0.2
