class_name Bubble extends Entity

@export var possible_hooks: Array[Item]
@export var air_ascend_velocity: float = 3.0
@export var air_sink_speed: float = 2.0
@export var move_noise: FastNoiseLite

@onready var shoot_timer: Timer = %ShootTimer
@onready var target_timer: Timer = %TargetTimer
@onready var body: Mandelbulb = %Mandelbulb
@onready var entity_detect: ShapeCast3D = %EntityDetect
@onready var floor_ray: RayCast3D = %FloorRayCast
@onready var entity_ray: RayCast3D = %EntityRayCast

enum {IDLE, TARGET_CHASE, }

var state: int
var wing_rotation: float = 0.0
var target: Entity
var target_velocity: Vector3
var time: float

func _ready() -> void :
    super._ready()

    var hook_item: Item = possible_hooks.pick_random()
    var new_item_state: ItemState = ItemState.new()
    new_item_state.initialize(hook_item)
    held_item_inventory.set_item(0, new_item_state)

    shoot_timer.timeout.connect(_on_shoot_timeout)
    target_timer.timeout.connect(_on_target_timeout)

    modulate_changed.connect(_on_modulate_changed)
    alpha_changed.connect(_on_alpha_changed)

    time = randf_range(0, 500)


func _on_modulate_changed(new_modulate: Color) -> void :
    body.set("instance_shader_parameters/albedo", new_modulate)


func _on_alpha_changed(new_alpha: float) -> void :
    body.set("instance_shader_parameters/fade", new_alpha)


func _physics_process(delta: float) -> void :
    if disabled or not is_session_position_loaded(global_position):
        return
    super._physics_process(delta)
    if is_future_position_loaded(delta):
        move_and_slide()

    time += delta
    wing_rotation += delta * 8.0
    body.rotation.y = wing_rotation

    gravity_velocity = Vector3()

    if state == IDLE:
        if floor_ray.is_colliding():
            target_velocity.y = air_ascend_velocity
        else:
            target_velocity.y = - air_sink_speed
        target_velocity.x = speed * (move_noise.get_noise_1d(0.8 * time) - 0.5)
        target_velocity.z = speed * (move_noise.get_noise_1d(0.8 * time + 7102.0) - 0.5)
    elif state == TARGET_CHASE:
        if not is_instance_valid(target):
            if is_interacting():
                held_item.interact_end()
            state = IDLE
        else:
            if is_interacting():
                if is_instance_valid(held_item) and is_instance_valid(held_item.hook) and is_instance_valid(held_item.hook.hook_entity):
                    target_velocity.y = 2.0 * air_ascend_velocity
                    target_velocity.x = 1.5 * speed * (move_noise.get_noise_1d(0.8 * time) - 0.5)
                    target_velocity.z = 1.5 * speed * (move_noise.get_noise_1d(0.8 * time + 7102.0) - 0.5)
            else:
                target_velocity = speed * global_position.direction_to(target.head.global_position - floor_ray.target_position)

    movement_velocity = lerp(movement_velocity, target_velocity, clamp(delta, 0.0, 1.0))

    super._physics_process(delta)
    move_and_slide()


func _on_shoot_timeout() -> void :
    if dead or disabled or state != TARGET_CHASE:
        return

    if is_interacting():
        held_item.interact_end()

    if entity_ray.is_colliding():
        var entity: Entity = entity_ray.get_collider() as Entity
        if not is_instance_valid(entity):
            return
        if not entity == target:
            return
    elif randf() < 0.8:
        return

    await get_tree().create_timer(1.0, false).timeout

    if is_instance_valid(held_item) and held_item.can_interact({}):
        held_item.interact(true, {})


func _on_target_timeout() -> void :
    if dead or disabled or state != IDLE:
        return
    get_target()
    if is_instance_valid(target):
        state = TARGET_CHASE


func get_look_direction() -> Vector3:
    return Vector3(0, -1, 0)


func get_target() -> void :
    var closest_entity: Entity = null
    for i in range(entity_detect.get_collision_count()):
        var object: Object = entity_detect.get_collider(i)
        var entity: Entity = object.owner
        if not is_instance_valid(entity) or entity.dead or entity.disabled or entity is Bubble or entity is Hamsa or entity is Ofanim:
            continue
        if not is_instance_valid(closest_entity):
            closest_entity = entity
        if entity.head.global_position.distance_to(global_position) < closest_entity.head.global_position.distance_to(global_position):
            closest_entity = entity
    target = closest_entity
