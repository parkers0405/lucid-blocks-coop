class_name Gel extends Entity

@export var bothersome_limit: int = 10

@export var jump_min_time: float = 2.0
@export var jump_max_time: float = 4.0
@export var jump_force_min: float = 1.0
@export var jump_force_max: float = 6.0
@export var jump_target_multiplier: float = 0.5
@export var base_color: Color = Color("78c4d0ff")
@export var idle_jump: bool = true

@onready var softbody: SoftBody3D = %GelModel / SoftBody3D
@onready var jump_timer: Timer = %JumpTimer
@onready var floor_ray: RayCast3D = %FloorRayCast3D
@onready var target_area: Area3D = %TargetArea3D
@onready var attack_area: Area3D = %AttackArea3D

var bothersome_entities: Array[Entity]
var bothersome: Entity
var last_position: Vector3
var last_softbody_position: Vector3
var approximate_velocity: Vector3

var color_1: Color
var color_2: Color


func _ready() -> void :
    super._ready()
    modulate_changed.connect(_on_modulate_changed)
    alpha_changed.connect(_on_alpha_changed)
    softbody.process_mode = Node.PROCESS_MODE_ALWAYS
    jump_timer.timeout.connect(_on_jump_timeout)

    target_area.body_entered.connect(_on_target_entered)
    target_area.body_exited.connect(_on_target_exited)
    attack_area.body_entered.connect(_on_body_entered_attack_area)

    jump_timer.start(randf_range(jump_min_time, jump_max_time))

    color_1 = base_color
    color_1 = Color.from_hsv(randf_range(0.0, 1.0), base_color.s, base_color.v)
    color_2 = Color.from_hsv(color_1.h + 0.5, base_color.s, base_color.v)
    update_colors()

    visible = false


func _on_body_entered_attack_area(body: Node3D) -> void :
    if dead or disabled or not is_instance_valid(body) or body is Gel or body.dead:
        return
    if approximate_velocity.length() < 4.0:
        return


    velocity = approximate_velocity
    %Attack.attack(body, global_position, 48.0 * weight / 0.5, 0.55)
    velocity = Vector3()


func _on_target_entered(body: Node3D) -> void :
    if len(bothersome_entities) > bothersome_limit:
        return
    if body is Gel:
        return
    bothersome_entities.append(body)
    update_bothersome_target()


func _on_target_exited(body: Node3D) -> void :
    var index: int = bothersome_entities.find(body)
    if index != -1:
        bothersome_entities.remove_at(index)
    update_bothersome_target()


func _on_jump_timeout() -> void :
    jump_timer.start(randf_range(jump_min_time, jump_max_time))

    if dead or disabled or softbody.process_mode == PROCESS_MODE_DISABLED:
        return

    if not floor_ray.is_colliding() or dead or disabled:
        return

    if not is_instance_valid(bothersome):
        if idle_jump:
            var random_direction: Vector3 = Vector3(randf_range(-1, 1), 1, randf_range(-1, 1)).normalized()
            softbody.apply_impulse(0, 32.0 * randf_range(jump_force_min, jump_force_max) * random_direction)
    else:
        var displacement: Vector3 = bothersome.global_position - global_position
        var distance: float = displacement.length()
        var jump_direction: Vector3 = (displacement.normalized() + Vector3(0, 1.0, 0)).normalized()
        softbody.apply_impulse(0, 56.0 * jump_direction.normalized() * max(jump_force_min, sqrt(distance) * jump_target_multiplier))

    %SlapPlayer.play()


func _physics_process(delta: float) -> void :
    if disabled:
        return

    if first_frame:
        softbody.process_mode = Node.PROCESS_MODE_ALWAYS
        first_frame = false
        return

    if not update_positions() or not is_session_position_loaded(global_position):
        softbody.process_mode = Node.PROCESS_MODE_DISABLED
        return

    softbody.process_mode = Node.PROCESS_MODE_ALWAYS
    distance_process_check()

    check_fire()
    check_water()

    if first_frame:
        first_frame = false
        return

    visible = true

    knockback_process(delta)
    rope_process(delta)


    if is_session_position_loaded( %CenterPoint.global_position) and Ref.world.is_block_solid_at( %CenterPoint.global_position):
        global_position.y += 1.0

    if knockback_velocity.length() > 0.1:
        softbody.apply_central_force(128.0 * knockback_velocity)
    if rope_velocity.length() > 0.1:
        softbody.apply_central_force(127.0 * rope_velocity)

    approximate_velocity = (global_position - last_position) / delta


func distance_process_check() -> void :
    super.distance_process_check()
    if not is_processing():
        softbody.process_mode = Node.PROCESS_MODE_DISABLED

func update_bothersome_target() -> void :
    bothersome = null

    bothersome_entities.shuffle()
    if len(bothersome_entities) == 0:
        return

    for entity in bothersome_entities:
        if not is_session_player_entity(bothersome):
            bothersome = entity

    if bothersome == null:
        bothersome = bothersome_entities.pick_random()



func get_softbody_approximate_position() -> Vector3:
    var average_position: Vector3 = Vector3()
    for index in [124, 125, 24, 25, 74, 75]:
        average_position += softbody.get_point_transform(index)
    return average_position / 6.0


func _on_modulate_changed(new_modulate: Color) -> void :
    softbody.set_instance_shader_parameter("albedo", new_modulate)


func _on_alpha_changed(new_alpha: float) -> void :
    softbody.set_instance_shader_parameter("fade", new_alpha)


func attacked(attacker: Entity, damage: int) -> void :
    if dead or disabled or softbody.process_mode == PROCESS_MODE_DISABLED:
        return

    if is_instance_valid(attacker):
        var knockback_strength: float = knockback_velocity.length()
        knockback_velocity = (get_softbody_approximate_position() - attacker.global_position) * knockback_strength
        super.attacked(attacker, damage)
        bothersome = attacker
    else:
        super.attacked(attacker, damage)


func update_positions() -> bool:
    last_position = global_position

    var approx_position: Vector3 = last_softbody_position
    if not softbody.process_mode == PROCESS_MODE_DISABLED:
        approx_position = get_softbody_approximate_position()
        last_softbody_position = approx_position
    var approx_position_loaded: bool = is_session_position_loaded(approx_position)
    if approx_position_loaded:
        global_position = approx_position
    return approx_position_loaded


func override_position() -> void :
    last_softbody_position = global_position
    softbody.global_position = global_position
    last_position = global_position


func preserve_save(file: SaveFile, uuid: String) -> void :
    super.preserve_save(file, uuid)
    file.set_data("node/%s/global_position" % uuid, global_position)
    file.set_data("node/%s/color_1" % uuid, color_1)
    file.set_data("node/%s/color_2" % uuid, color_2)


func preserve_load(file: SaveFile, uuid: String) -> void :
    super.preserve_load(file, uuid)
    color_1 = file.get_data("node/%s/color_1" % uuid, Color.BISQUE)
    color_2 = file.get_data("node/%s/color_2" % uuid, Color.BISQUE)

    override_position()
    update_colors()


func update_colors() -> void :
    softbody.set_instance_shader_parameter("color1", color_1)
    softbody.set_instance_shader_parameter("color2", color_2)
