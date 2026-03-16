class_name Ofanim extends Entity

@export var life_time_min: float = 60.0
@export var life_time_max: float = 300.0
@export var move_speed: float = 0.25
@export var offset: Vector3
@export var random_radius: float = 20.0

@onready var fractal: Mandelbulb = %Mandelbulb

enum {IDLE, ANGRY}

var state: int = IDLE


func _ready() -> void :
    super._ready()

    offset += Vector3(randf() - 0.5, 0.1 * (randf() - 0.5), randf() - 0.5) * random_radius
    %LifeTimer.start(randf_range(life_time_min, life_time_max))
    %LifeTimer.timeout.connect(_on_timeout)

    modulate_changed.connect(_on_modulate_changed)
    alpha_changed.connect(_on_alpha_changed)


func _on_modulate_changed(new_modulate: Color) -> void :
    fractal.set("instance_shader_parameters/albedo", new_modulate)


func _on_alpha_changed(new_alpha: float) -> void :
    fractal.set("instance_shader_parameters/fade", new_alpha)


func _on_timeout() -> void :
    queue_free()


func _physics_process(_delta: float) -> void :
    pass


func _get_target_position() -> Vector3:
    return get_session_target_entity_position(global_position, Ref.player)


func _get_target_head_position() -> Vector3:
    return get_session_target_entity_head_position(global_position + Vector3(0, 1.45, 0), Ref.player)


func _process(delta: float) -> void :
    if disabled or not is_session_position_loaded(global_position):
        return

    distance_process_check()

    if state == IDLE:
        var center: Vector3 = _get_target_position()
        var target_position: Vector3 = center + offset
        var new_global_position = lerp(global_position, target_position, delta * move_speed)
        if is_session_position_loaded(new_global_position):
            global_position = new_global_position
        SpatialMath.look_at(self, _get_target_head_position())


func looked_at_by_player() -> void :
    queue_free()
