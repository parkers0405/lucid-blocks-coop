class_name Shark extends Entity

@onready var body: MeshInstance3D = %Body
@onready var beak: MeshInstance3D = %Beak
@onready var wall_ray: RayCast3D = %WallRayCast3D
@onready var attack_shape: ShapeCast3D = %AttackShapeCast3D
@onready var flounder_timer: Timer = %FlounderTimer

@export var uncollide_accel: float = 0.5
@export var spin_per_speed: float = 0.1
@export var movement_noise: FastNoiseLite

var uncollide_velocity: Vector3
var target_velocity: Vector3
var direction: Vector3
var time: float
var actual_speed: float

func _ready() -> void :
    super._ready()
    modulate_changed.connect(_on_modulate_changed)
    alpha_changed.connect(_on_alpha_changed)
    time = randf_range(0, 100)


func _on_modulate_changed(new_modulate: Color) -> void :
    beak.set_instance_shader_parameter("albedo_2", new_modulate)
    body.set_instance_shader_parameter("albedo_2", new_modulate)


func _on_alpha_changed(new_alpha: float) -> void :
    beak.set_instance_shader_parameter("fade", new_alpha)
    body.set_instance_shader_parameter("fade_2", new_alpha)


func _get_target_entity():
    var underwater_target = _get_nearest_underwater_session_player()
    if is_instance_valid(underwater_target):
        return underwater_target
    return get_session_target_entity(Ref.player)


func _get_nearest_underwater_session_player():
    var nearest = null
    var nearest_distance_squared: float = INF

    if is_instance_valid(Ref.player) and Ref.player.under_water:
        nearest = Ref.player
        nearest_distance_squared = global_position.distance_squared_to(Ref.player.global_position)

    if Ref.coop_manager == null:
        return nearest

    var active_instance_key: String = Ref.coop_manager.get_active_dimension_instance_key()
    for peer_id in Ref.coop_manager.remote_player_proxies.keys():
        var proxy = Ref.coop_manager.get_remote_player_proxy(int(peer_id))
        if not is_instance_valid(proxy) or proxy.dead or proxy.disabled or not proxy.under_water or not proxy.is_inside_tree():
            continue
        var state: Dictionary = Ref.coop_manager.peer_states.get(peer_id, {})
        if not bool(state.get("active", false)) or str(state.get("dimension_instance_key", "")) != active_instance_key:
            continue
        var distance_squared: float = global_position.distance_squared_to(proxy.global_position)
        if distance_squared >= nearest_distance_squared:
            continue
        nearest = proxy
        nearest_distance_squared = distance_squared

    return nearest


func _physics_process(delta: float) -> void :
    if disabled or not is_session_position_loaded(global_position):
        return
    super._physics_process(delta)
    if is_future_position_loaded(delta):
        move_and_slide()

    time += delta * 0.1

    if not under_water and flounder_timer.is_stopped():
        flounder_timer.start()

    if flounder_timer.is_stopped():
        gravity_velocity = Vector3()

    var target_entity = _get_target_entity()
    if is_instance_valid(target_entity) and target_entity.under_water:
        var target_head: Vector3 = target_entity.head.global_position if is_instance_valid(target_entity.head) else target_entity.global_position + Vector3(0, 1.45, 0)
        if target_head.distance_to(hand.global_position) > 8.0:
            target_velocity = hand.global_position.direction_to(target_head)
        actual_speed = lerp(actual_speed, speed * (1.0 if under_water else 0.5), clamp(delta, 0.0, 1.0))
    else:
        target_velocity = (Vector3(sin(time) * 0.05 + cos(time + time) * 0.7, -0.05 + 0.0 * sin(time) + 0.1 * cos(time), 0.2 * sin(time + time) + 0.2 * cos(time)).normalized())
        actual_speed = lerp(actual_speed, 0.25 * speed * (1.0 if under_water else 0.5), clamp(delta, 0.0, 1.0))

    if wall_ray.is_colliding():
        var target_position: Vector3 = (wall_ray.get_collision_point() - wall_ray.get_collision_normal() * 0.5).floor()
        if hand.global_position.distance_to(target_position) < 5.0:
            %BreakBlocks.break_block_instant(target_position)
        uncollide_velocity = lerp(uncollide_velocity, - movement_velocity.normalized(), clamp(delta * uncollide_accel, 0.0, 1.0))
    else:
        uncollide_velocity = lerp(uncollide_velocity, Vector3(), clamp(delta * uncollide_accel, 0.0, 1.0))

    direction = lerp(direction, 1.25 * uncollide_velocity + target_velocity, clamp(0.25 * delta, 0.0, 1.0))
    movement_velocity = actual_speed * (direction + 0.5 * Vector3(movement_noise.get_noise_1d(8.0 * time), movement_noise.get_noise_1d(12.0 * time + 2.0), movement_noise.get_noise_1d(8.0 * time + 6.0))).normalized()

    body.rotation.x += delta * spin_per_speed * velocity.length()
    SpatialMath.look_at_local(rotation_pivot, - movement_velocity.normalized())

    attack_entities()

func attack_entities() -> void :
    if Vector3(velocity.x, 0, velocity.z).length() < 6.0:
        return
    for i in range(attack_shape.get_collision_count()):
        var collider = attack_shape.get_collider(i)
        var target = _resolve_attack_target(collider)
        if not is_instance_valid(target):
            continue
        if not (target is Entity or is_session_player_entity(target)):
            continue
        if target == self or target.dead or target.disabled:
            continue
        %Attack.attack(target, hand.global_position, 24.0, 0.25)


func _resolve_attack_target(collider):
    if not is_instance_valid(collider):
        return null
    if collider is Area3D:
        if collider.has_meta("coop_proxy_owner"):
            return collider.get_meta("coop_proxy_owner")
        if is_instance_valid(collider.owner):
            return collider.owner
        if is_instance_valid(collider.get_parent()):
            return collider.get_parent()
        return null
    return collider if collider is Node3D else null
