class_name Glaggler extends Entity

@export var drift_strength = 2.0
@export var max_drift_speed: float = 5.0
@export var bounciness: float = 0.7

@onready var model: MeshInstance3D = %GlagglerModel

var look_direction: Vector3

func _ready() -> void :
    super._ready()
    modulate_changed.connect(_on_modulate_changed)
    alpha_changed.connect(_on_alpha_changed)
    died.connect(_on_died)
    movement_velocity = Vector3(randf(), randf(), randf()).normalized()
    look_direction = movement_velocity


func _on_died() -> void :
    %PopPlayer.play("explode")


func _on_modulate_changed(new_modulate: Color) -> void :
    model.set("instance_shader_parameters/albedo", new_modulate)


func _on_alpha_changed(new_alpha: float) -> void :
    model.set("instance_shader_parameters/fade", new_alpha)


func _physics_process(delta: float) -> void :
    if disabled or not is_session_position_loaded(global_position):
        return
    gravity_velocity = Vector3()
    super._physics_process(delta)
    if is_future_position_loaded(delta):
        move_and_slide()


    var nudge: Vector3 = Vector3(
        randf_range(-1, 1), 
        randf_range(-1, 1), 
        randf_range(-1, 1)
    ).normalized() * speed * delta

    movement_velocity += nudge
    movement_velocity = movement_velocity.limit_length(max_drift_speed)

    if is_instance_valid(get_last_slide_collision()):
        var collision: KinematicCollision3D = get_last_slide_collision()
        var normal: Vector3 = collision.get_normal()
        movement_velocity = movement_velocity.bounce(normal) * bounciness

    look_direction = lerp(look_direction, Vector3(movement_velocity.x, 0, movement_velocity.z).normalized(), delta * 0.2)
    SpatialMath.look_at_local(rotation_pivot, look_direction)
