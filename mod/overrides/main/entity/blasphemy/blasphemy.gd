class_name Blasphemy extends Entity

@export var attack_timeout: float = 0.5
@export var max_targets: int = 8
@export var attack_distance: float = 1.25

@export_group("Leg and Body Parameters")
@export var leg_count: int = 4
@export var leg_rest_distance: float = 0.4
@export var leg_target_initial_distance: float = 0.6
@export var step_ray_length: float = 1.5
@export var reset_distance: float = 0.25
@export var body_offset: float = 0.25
@export var body_readjust_speed: float = 16.0
@export var spring_constant: float = 16.0
@export var spring_dampening: float = 0.1
@export var restick_speed: float = 0.5
@export var leg_collision: bool = true
@export var leg_span: float = 2 * PI
@export var jumpy: bool = false

@export_group("Other")
@export var ik_leg_scene: PackedScene
@export var kill_achievement: bool = false

var legs: Array[IKLeg]
var leg_rests: Array[Marker3D]
var leg_targets: Array[Marker3D]
var leg_rays: Array[RayCast3D]
var unstick: float = 0.0
var desired_velocity: Vector3 = Vector3.ZERO
var near_entities: Array = []
var attacked_by_player: bool = false
var stuck_impulse: Vector3
var chase_target_override = null


func _ready() -> void:
    super._ready()
    distance_process_check()
    on_attacked.connect(_on_attacked)
    %AttackTimer.timeout.connect(_on_attack_timeout)
    %AttackTargets.body_entered.connect(_on_body_entered_attack)
    %AttackTargets.body_exited.connect(_on_body_exited_attack)
    if jumpy:
        %StuckTimer.timeout.connect(_on_stuck_timeout)
    for i in range(leg_count):
        var angle: float = PI / 2.0 + i * leg_span / leg_count

        var new_leg: IKLeg = ik_leg_scene.instantiate()
        %Legs.add_child(new_leg)
        new_leg.global_position = global_position
        new_leg.rotation.y = -angle
        new_leg.root = %CenterPoint
        legs.append(new_leg)

        var new_rest := Marker3D.new()
        %LegRests.add_child(new_rest)
        new_rest.position = Vector3(sin(angle), 0, -cos(angle)) * leg_rest_distance
        leg_rests.append(new_rest)

        var new_target := Marker3D.new()
        %LegTargets.add_child(new_target)
        new_target.global_position = global_position
        new_target.global_position += Vector3(sin(angle), 0, -cos(angle)) * leg_rest_distance
        leg_targets.append(new_target)
        new_leg.target = new_target

        var new_ray := RayCast3D.new()
        %LegRays.add_child(new_ray)
        new_ray.position = Vector3(sin(angle) * leg_rest_distance, step_ray_length * 0.35, -cos(angle) * leg_rest_distance)
        new_ray.target_position = Vector3(0, -step_ray_length, 0)
        leg_rays.append(new_ray)

        new_leg.hit_ground.connect(_on_leg_hit_ground)

        if leg_collision:
            new_leg.initialize_leg_areas(self)

        new_leg.initialize_leg_modulates(self)
    modulate_changed.connect(_on_modulate_changed)
    alpha_changed.connect(_on_alpha_changed)


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
        %VisibleOnScreenEnabler3D.enable_node_path = "" if near_session_player or not disabled_by_visibility else ".."
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


func _get_chase_target():
    var fallback = chase_target_override if is_instance_valid(chase_target_override) else (Ref.player if is_instance_valid(Ref.player) else null)
    if not _use_session_targeting():
        return fallback
    return Ref.coop_manager.get_preferred_session_player_entity(global_position, chase_target_override, fallback)


func _on_body_entered_attack(body: Node3D) -> void:
    if body == self:
        return
    if near_entities.size() > max_targets:
        return
    if not near_entities.has(body):
        near_entities.append(body)
    if not near_entities.is_empty() and has_node("%AttackTimer") and %AttackTimer.is_stopped():
        _on_attack_timeout()
        %AttackTimer.start(attack_timeout)


func _on_body_exited_attack(body: Node3D) -> void:
    near_entities.erase(body)
    if near_entities.is_empty() and is_inside_tree() and has_node("%AttackTimer"):
        %AttackTimer.stop()


func _on_stuck_timeout() -> void:
    if dead or not is_inside_tree() or disabled:
        return
    if is_on_wall() and jumpy and stuck_impulse.length() < 32.0:
        stuck_impulse = Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5)).normalized() * 96.0


func _on_attack_timeout() -> void:
    if dead or disabled:
        return
    %AttackAnimationPlayer.play("attack")
    for entity in near_entities:
        if is_instance_valid(entity) and entity.global_position.distance_to(global_position) < attack_distance:
            %Attack.attack(entity, entity.global_position, 50.0)


func _on_modulate_changed(new_modulate: Color) -> void:
    %Core.set("instance_shader_parameters/albedo", new_modulate)


func _on_alpha_changed(new_alpha: float) -> void:
    %Core.set("instance_shader_parameters/fade", new_alpha)


func _on_leg_hit_ground(ground_position: Vector3) -> void:
    %Step.step_ik(ground_position)


func _process(_delta: float) -> void:
    pass


func leg_process() -> Array[float]:
    var total_displacement: float = 0.0
    var applying_force: int = 0
    for i in range(legs.size()):
        if legs[i].on_ground:
            if leg_rays[i].is_colliding():
                leg_targets[i].global_position = leg_rays[i].get_collision_point()
            else:
                leg_targets[i].global_position = leg_rests[i].global_position

            if not legs[i].is_animating and legs[i].foot_position.distance_to(leg_targets[i].global_position) > reset_distance:
                if (not legs[i - 1].is_animating or legs[i - 1].is_steady) and (not legs[(i + 1) % legs.size()].is_animating or legs[(i + 1) % legs.size()].is_steady):
                    legs[i].start_step_animation()

            if global_position.y - body_offset < leg_targets[i].global_position.y:
                total_displacement += leg_targets[i].global_position.y - global_position.y + body_offset
                applying_force += 1
        elif not legs[i].is_animating:
            if leg_rays[i].is_colliding():
                leg_targets[i].global_position = leg_rays[i].get_collision_point()
            else:
                leg_targets[i].global_position = leg_rays[i].to_global(leg_rays[i].target_position)
            legs[i].reset()
    return [total_displacement, float(applying_force)]


func spring_process(delta: float, total_displacement: float, applying_force: float) -> void:
    movement_velocity.y -= delta * jump_dampening
    if movement_velocity.y < 0 or is_on_floor():
        movement_velocity.y = 0

    movement_velocity.y += (1.0 - unstick) * (delta * spring_constant * total_displacement / float(leg_count) - velocity.y * spring_dampening * applying_force / leg_count)
    unstick = lerp(unstick, 0.0, clampf(delta * restick_speed, 0.0, 1.0))
    unstick = clampf(unstick, 0.0, 1.0)


func _physics_process(delta: float) -> void:
    if disabled or not _is_session_position_loaded(global_position):
        return
    distance_process_check()
    if is_future_position_loaded(delta):
        move_and_slide()

    var results: Array[float] = leg_process()
    var total_displacement: float = results[0]
    var applying_force: float = results[1]

    spring_process(delta, total_displacement, applying_force)

    velocity = movement_velocity + gravity_velocity + knockback_velocity + rope_velocity

    rope_process(delta)
    gravity_process(delta)
    knockback_process(delta)

    var vertical_movement_velocity: float = movement_velocity.y
    movement_velocity = lerp(movement_velocity, stuck_impulse + desired_velocity, minf(1.0, delta * ground_accel))
    movement_velocity.y = vertical_movement_velocity

    stuck_impulse = lerp(stuck_impulse, Vector3.ZERO, minf(1.0, delta * ground_accel))

    var chase_target = _get_chase_target()
    if not is_instance_valid(chase_target) or chase_target.dead:
        desired_velocity = Vector3.ZERO
        return

    var dir: Vector3 = (chase_target.global_position - global_position).normalized()
    dir.y = 0.0
    desired_velocity.x = dir.x * speed
    desired_velocity.z = dir.z * speed


func die() -> void:
    if attacked_by_player and kill_achievement:
        Steamworks.set_achievement("BLASPHEMY")
    super.die()


func _on_attacked(attacker) -> void:
    if _is_session_player_entity(attacker):
        attacked_by_player = true
        chase_target_override = attacker
    if jumpy and randf() < 0.1 and stuck_impulse.length() < 32.0:
        stuck_impulse = Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5)).normalized() * 96.0
