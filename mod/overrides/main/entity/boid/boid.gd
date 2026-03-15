class_name Boid extends Entity

@export var max_boids: int = 8
@export var separation: float = 0.5
@export var alighment: float = 0.5
@export var cohesion: float = 0.5
@export var rotate_axis: bool = false
@export var skip_update_chance: float = 0.65

@onready var boid_model: EntityModel = %BoidModel

var boids: Array[Boid]
var acceleration: Vector3
var look_direction: Vector3
var angle: float = 0.0

func _ready() -> void :
    super._ready()
    %BoidArea3D.body_entered.connect(_on_boid_entered)
    %BoidArea3D.body_exited.connect(_on_boid_exited)
    movement_velocity = (Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized())
    angle = randf_range(0, 2 * PI)
    if rotate_axis:
        %BoidModel.rotation.z = angle


func _on_boid_entered(body: Node) -> void :
    if not body is Boid:
        return

    var boid: Boid = body as Boid
    if len(boids) >= max_boids:
        return
    boids.append(boid)


func _on_boid_exited(body: Node) -> void :
    if not body is Boid:
        return

    var boid: Boid = body as Boid
    var index: int = boids.find(boid)
    if index != -1:
        boids.remove_at(index)


func _get_target_position() -> Vector3:
    return get_session_target_position(Ref.player.global_position if is_instance_valid(Ref.player) else global_position)


static func _cohesion(delta: float, pos: Vector3, boid_array: Array, boid_cohesion: float) -> Vector3:
    if len(boid_array) == 0:
        return Vector3()

    var average_position: Vector3 = Vector3()
    for boid in boid_array:
        average_position += boid.global_position
    average_position /= len(boid_array)

    var direction: Vector3 = average_position - pos
    return direction * boid_cohesion * delta


static func _separation(delta: float, pos: Vector3, boid_array: Array, boid_separation: float) -> Vector3:
    var acceleration_sum: Vector3 = Vector3()
    for boid in boid_array:
        var distance_multiplier: float = 1.0 - pos.distance_to(boid.global_position) / 3.0
        var direction: Vector3 = - pos.direction_to(boid.global_position)
        acceleration_sum += direction * distance_multiplier * boid_separation * delta
    return acceleration_sum


static func _alignment(delta: float, _pos: Vector3, boid_array: Array, boid_alignment: float) -> Vector3:
    if len(boid_array) == 0:
        return Vector3()

    var average_velocity: Vector3 = Vector3()
    for boid in boid_array:
        average_velocity += boid.movement_velocity.normalized()
    average_velocity /= len(boid_array)
    return average_velocity * boid_alignment * delta


func _detect(delta: float) -> void :
    var global_point: Vector3 = %DetectRay3D.to_global( %DetectRay3D.target_position)
    if %DetectRay3D.is_colliding():
        acceleration += ( %CenterPoint.global_position - global_point).normalized() * delta * 8.0


    var distance_vector: Vector3 = _get_target_position() - global_position
    acceleration += 0.1 * distance_vector * delta


func clean_up_boids() -> void :
    var new_boids: Array[Boid] = []
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

    angle += delta * 1.0 * acceleration.length()
    if rotate_axis:
        %BoidModel.rotation.z = angle

    look_direction = lerp(look_direction, movement_velocity, delta * 6.5)

    boid_model.rotation.z = lerp_angle(boid_model.rotation.z, 0, delta * 8)

    if movement_velocity.length() > speed * speed_modifier:
        movement_velocity = movement_velocity.normalized() * speed * speed_modifier
    if acceleration.length() > 8.0:
        acceleration = acceleration.normalized() * 8.0
    gravity_velocity = Vector3()

    if randf() > skip_update_chance:
        if len(boids) > 0:
            acceleration += _cohesion(delta, global_position, boids, cohesion)
            acceleration += _alignment(delta, global_position, boids, alighment)
            acceleration += _separation(delta, global_position, boids, separation)
        _detect(delta)

    movement_velocity += acceleration * delta * 3.0
    var target_position: Vector3 = %RotationPivot.global_position + look_direction.normalized()
    SpatialMath.look_at( %RotationPivot, target_position)
