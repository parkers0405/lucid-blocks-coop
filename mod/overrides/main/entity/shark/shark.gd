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
    if not _use_server_session_targeting():
        return Ref.player
    return Ref.coop_manager.get_nearest_session_player_entity(global_position, Ref.player)


func _physics_process(delta: float) -> void :
    if disabled or not Ref.world.is_position_loaded(global_position):
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
        var area: Area3D = attack_shape.get_collider(i)
        if not is_instance_valid(area):
            continue
        var entity: Entity = area.owner
        if entity == self or not is_instance_valid(entity) or entity.dead or entity.disabled:
            continue
        %Attack.attack(entity, hand.global_position, 24.0, 0.25)
