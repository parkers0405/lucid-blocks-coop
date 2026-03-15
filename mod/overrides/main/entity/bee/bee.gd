class_name Bee extends Entity

@export var max_boids: int = 8
@export var separation: float = 0.5
@export var alighment: float = 0.5
@export var cohesion: float = 0.5
@export var flap_speed: float = 16.0
@export var skip_update_chance: float = 0.65

@onready var body_model: Node3D = %BodyModel

var boids: Array[Bee]
var acceleration: Vector3
var look_direction: Vector3
var time: float
var jerk: Vector3


func _ready() -> void :
    super._ready()

    time = randf_range(0, 100)
    wing_update()

    %BoidArea3D.body_entered.connect(_on_boid_entered)
    %BoidArea3D.body_exited.connect(_on_boid_exited)

    movement_velocity = (Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized())

    modulate_changed.connect(_on_modulate_changed)
    alpha_changed.connect(_on_alpha_changed)
    on_attacked.connect(_on_attacked)


func _on_attacked(_attacker: Entity) -> void :
    jerk += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()


func _on_modulate_changed(new_modulate: Color) -> void :
    for segment in body_model.get_children() + %WingHolder1.get_children() + %WingHolder2.get_children():
        segment.set("instance_shader_parameters/albedo", new_modulate)


func _on_alpha_changed(new_alpha: float) -> void :
    for segment in body_model.get_children() + %WingHolder1.get_children() + %WingHolder2.get_children():
        segment.set("instance_shader_parameters/fade", new_alpha)


func _on_boid_entered(body: Node) -> void :
    if not body is Bee:
        return

    var boid: Bee = body as Bee
    if len(boids) >= max_boids:
        return
    boids.append(boid)


func _on_boid_exited(body: Node) -> void :
    if not body is Bee:
        return

    var boid: Bee = body as Bee
    var index: int = boids.find(boid)
    if index != -1:
        boids.remove_at(index)


func _get_target_position() -> Vector3:
    return get_session_target_position(Ref.player.global_position if is_instance_valid(Ref.player) else global_position)


func _detect(delta: float) -> void :
    var global_point: Vector3 = %DetectRay3D.to_global( %DetectRay3D.target_position)
    if %DetectRay3D.is_colliding():
        acceleration += ( %CenterPoint.global_position - global_point).normalized() * delta * 6.0


    var distance_vector: Vector3 = _get_target_position() - global_position
    acceleration += 0.1 * distance_vector * delta


func clean_up_boids() -> void :
    var new_boids: Array[Bee] = []
    for boid in boids:
        if is_instance_valid(boid) and boid.is_inside_tree() and not boid.dead:
            new_boids.append(boid)
    boids = new_boids


func _physics_process(delta: float) -> void :
    if disabled or not Ref.world.is_position_loaded(global_position):
        return
    super._physics_process(delta)
    if is_future_position_loaded(delta):
        move_and_slide()

    time += delta * flap_speed

    wing_update()

    look_direction = lerp(look_direction, movement_velocity, delta * 2.0)
    body_model.rotation.z = lerp_angle(body_model.rotation.z, 0, delta * 8)

    if movement_velocity.length() > speed * speed_modifier:
        movement_velocity = movement_velocity.normalized() * speed * speed_modifier
    if acceleration.length() > 8.0:
        acceleration = acceleration.normalized() * 8.0
    gravity_velocity = Vector3()

    jerk = lerp(jerk, Vector3(), clamp(delta, 0.0, 1.0))
    if randf() > skip_update_chance:
        if len(boids) > 0:
            acceleration += Boid._cohesion(delta, global_position, boids, cohesion)
            acceleration += Boid._alignment(delta, global_position, boids, alighment)
            acceleration += Boid._separation(delta, global_position, boids, separation)
        _detect(delta)

    movement_velocity += acceleration * delta * 2.5 + jerk * delta * 4.0
    var target_position: Vector3 = %RotationPivot.global_position + look_direction.normalized()
    SpatialMath.look_at( %RotationPivot, target_position)


func wing_update() -> void :
    %WingHolder1.rotation_degrees.z = lerp(-40, 0, 0.5 + 0.5 * sin(time))
    %WingHolder2.rotation_degrees.z = lerp(40, 0, 0.5 + 0.5 * sin(time))
