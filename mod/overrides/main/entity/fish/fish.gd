class_name Fish extends Entity

@export var can_fly: bool = false
@export var max_boids: int = 8
@export var separation: float = 0.5
@export var alighment: float = 0.5
@export var cohesion: float = 0.5
@export var skip_update_chance: float = 0.65


@onready var fish_model: FishModel = %FishModel

enum {SUBMERGED, AIR}

var state: int = AIR
var boids: Array[Fish]
var acceleration: Vector3
var look_direction: Vector3


func _ready() -> void :
    super._ready()

    %BoidArea3D.body_entered.connect(_on_boid_entered)
    %BoidArea3D.body_exited.connect(_on_boid_exited)
    movement_velocity = (Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized())


func _on_boid_entered(body: Node) -> void :
    if not body is Fish:
        return

    var boid: Fish = body as Fish
    if len(boids) >= max_boids:
        return
    boids.append(boid)


func _on_boid_exited(body: Node) -> void :
    if not body is Fish:
        return

    var boid: Fish = body as Fish
    var index: int = boids.find(boid)
    if index != -1:
        boids.remove_at(index)


func _get_target_position() -> Vector3:
    return get_session_target_entity_position(global_position, Ref.player)


func _detect(delta: float) -> void :
    var global_point: Vector3 = %DetectRay3D.to_global( %DetectRay3D.target_position)
    if %DetectRay3D.is_colliding():
        acceleration += ( %CenterPoint.global_position - global_point).normalized() * delta * 6.0
    var above_point: Vector3 = %CenterPoint.global_position + Vector3(0, 1.5, 0)

    if not can_fly:

        if is_session_position_loaded(above_point) and not Ref.world.is_block_solid_at(above_point) and not Ref.world.is_under_water(above_point):
            acceleration += (Vector3(0, -1, 0) * delta * 12.0 * (0.1 + Vector3(0, 1, 0).dot(movement_velocity.normalized())))
    else:

        var distance_vector: Vector3 = _get_target_position() - global_position
        acceleration += 0.1 * distance_vector * delta


func clean_up_boids() -> void :
    var new_boids: Array[Fish] = []
    for boid in boids:
        if is_instance_valid(boid) and boid.is_inside_tree() and not boid.dead:
            new_boids.append(boid)
    boids = new_boids


func _physics_process(delta: float) -> void :
    if disabled or not is_session_position_loaded(global_position):
        return
    super._physics_process(delta)
    if is_future_position_loaded(delta):
        move_and_slide()
    state = SUBMERGED if can_fly or under_water else AIR

    if state == AIR:
        movement_velocity = lerp(movement_velocity, Vector3(), delta)
        acceleration = lerp(acceleration, Vector3(), delta)

        fish_model.rotation.z = lerp_angle(fish_model.rotation.z, 1.5708, delta * 8)
        fish_model.panic = lerp(fish_model.panic, 1.0, delta * 8)
        look_direction = lerp(look_direction, Vector3(0, 0, 1), delta * 1.0)
    else:
        look_direction = lerp(look_direction, movement_velocity, delta * 6.0)

        fish_model.rotation.z = lerp_angle(fish_model.rotation.z, 0, delta * 8)
        fish_model.panic = lerp(fish_model.panic, 0.0, delta * 8)

        if movement_velocity.length() > speed * speed_modifier:
            movement_velocity = movement_velocity.normalized() * speed * speed_modifier
        if acceleration.length() > 8.0:
            acceleration = acceleration.normalized() * 8.0
        gravity_velocity = Vector3()

        if randf() > skip_update_chance:
            if len(boids) > 0:
                acceleration += Boid._cohesion(delta, global_position, boids, cohesion)
                acceleration += Boid._alignment(delta, global_position, boids, alighment)
                acceleration += Boid._separation(delta, global_position, boids, separation)
            _detect(delta)
    movement_velocity += acceleration * delta * 3.0
    fish_model.speed = lerp(fish_model.speed, velocity.length() / (speed * speed_modifier), delta * 3.0)
    var target_position: Vector3 = %RotationPivot.global_position + look_direction.normalized()
    SpatialMath.look_at( %RotationPivot, target_position)
