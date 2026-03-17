class_name Kodama extends Entity

@export var explosion_scene: PackedScene
@export var core_models: Array[Mesh]
@export var anger_threshold: float = 1.0
@export var hostile_noise: float = 0.5
@export var break_trigger_distance: float = 5.0
@export var break_anger_min: float = 0.05
@export var break_anger_max: float = 0.25
@export var spin_speed_idle: float = 3.0
@export var spin_speed_hostile: float = 1.0
@export var spin_speed_accel: float = 1.0
@export var attack_anger: float = 1.0
@export var attack_begin_distance: float = 3.0
@export var attack_actual_distance: float = 1.5
@export var death_explosion: bool = false

enum {
    IDLE, 
    HOSTILE, 
}

var variant: int = 0:
    set(val):
        variant = val
        %Core.mesh = core_models[variant]


var time: float = 0.0


var spin_speed: float = 1.0


var exploded: bool = false
var player
var attack_target: Entity
var state: int = IDLE
var anger: float = 0.0:
    set(val):
        anger = val

        if state == IDLE and anger >= anger_threshold:
            state = HOSTILE
            if not is_instance_valid(attack_target):
                attack_target = get_session_target_entity(Ref.player)
var desired_direction: Vector3

signal attack_frame


func _ready() -> void :
    super._ready()

    %DetectionArea3D.body_entered.connect(_on_body_entered)
    %DetectionArea3D.body_exited.connect(_on_body_exited)

    attack_frame.connect(_on_attack_frame)

    Ref.world.block_broken.connect(_on_block_broken)
    Ref.world.block_placed.connect(_on_block_placed)
    modulate_changed.connect(_on_modulate_changed)
    on_attacked.connect(_on_attacked)
    died.connect(_on_died)

    time = randf_range(0, 32.0)
    variant = randi_range(0, len(core_models) - 1)

    water_entered.connect(_on_water_entered)


func _on_water_entered(_velocity: float) -> void :
    explode.call_deferred()


func explode() -> void :
    if exploded or disabled or not is_inside_tree():
        return
    exploded = true
    var explosion: Explosion = explosion_scene.instantiate()
    get_tree().get_root().add_child(explosion)
    explosion.global_position = global_position
    explosion.entity_owner = self
    explosion.explode()
    health = 0


func _on_died() -> void :
    if death_explosion:
        explode()
    %AttackAnimationPlayer.stop()
    var tween: Tween = get_tree().create_tween().set_parallel(true)
    tween.tween_property( %Light, "light_energy", 0, 0.7)
    tween.tween_property( %AngerHum, "volume_db", -80, 0.7)
    tween.tween_property( %ElectricZap, "volume_db", -80, 0.7)


func _on_attack_frame() -> void :
    if dead or disabled or not is_instance_valid(attack_target) or attack_target.dead:
        return
    if attack_target.head.global_position.distance_to( %Core.global_position) > attack_actual_distance:
        return
    %Attack.attack(attack_target, global_position, 24.0)


func _on_attacked(attacker: Entity) -> void :
    if is_instance_valid(attacker):
        attack_target = attacker
        anger += attack_anger


func _on_body_entered(body: Node3D) -> void :
    if is_session_player_entity(body):
        player = body


func _on_body_exited(body: Node3D) -> void :
    if body == player:
        player = null


func _on_block_broken(break_position: Vector3i) -> void :
    if is_instance_valid(player) and break_position.distance_to(global_position) <= break_trigger_distance:
        anger += randf_range(break_anger_min, break_anger_max)


func _on_block_placed(place_position: Vector3) -> void :
    if is_instance_valid(player) and place_position.distance_to(global_position) <= break_trigger_distance:
        anger += randf_range(break_anger_min, break_anger_max)


func _on_modulate_changed(new_modulate: Color) -> void :
    %Core.set_instance_shader_parameter("alpha", alpha)
    %Core.set_instance_shader_parameter("line_color", new_modulate)
    %Core.set_instance_shader_parameter("glow_color", new_modulate)


func _process(delta: float) -> void :
    %Core.rotation.z += delta * 2.0 * spin_speed
    %Core.rotation.x += delta * 1.0 * spin_speed

    if not dead:
        %AngerHum.volume_linear = (0.6 * lerp( %AngerHum.volume_linear, clamp(anger / anger_threshold, 0.0, 1.0), delta))

    var target_spin_speed: float = spin_speed_idle

    match state:
        IDLE:
            target_spin_speed = spin_speed_idle
            %Core.set_instance_shader_parameter("straight_lines", false)
        HOSTILE:
            target_spin_speed = spin_speed_hostile
            %Core.set_instance_shader_parameter("straight_lines", true)
    spin_speed = lerp(spin_speed, target_spin_speed, delta * spin_speed_accel)


func _physics_process(delta: float) -> void :
    if disabled or not is_session_position_loaded(global_position):
        return
    gravity_velocity = Vector3()
    super._physics_process(delta)
    if is_future_position_loaded(delta):
        move_and_slide()

    if _use_session_targeting() and Ref.coop_manager.is_position_near_same_instance_player(global_position, process_distance):
        var session_target = get_session_target_entity(attack_target if is_instance_valid(attack_target) else player)
        if is_instance_valid(session_target):
            player = session_target
            attack_target = session_target


    time += delta * 0.5
    if time > 32.0:
        time = 0.0

    var next_direction: Vector3


    if state == IDLE or not is_instance_valid(attack_target):
        next_direction = (Vector3(sin(time) * 0.2 + cos(time + time) * 0.3, -0.01 + 0.05 * sin(time) + 0.1 * cos(time), 0.2 * sin(time + time) + 0.2 * cos(time)).normalized())
    elif state == HOSTILE:
        if not is_instance_valid(attack_target):
            attack_target = get_session_target_entity(Ref.player)
        if is_instance_valid(attack_target):
            var to_target_direction: Vector3 = (attack_target.head.global_position - %Core.global_position).normalized()
            var noise: Vector3 = Vector3(sin(time) * 0.2 + cos(time + time) * 0.3, 0.05 * sin(time) + 0.1 * cos(time), 0.2 * sin(time + time) + 0.2 * cos(time)).normalized()
            next_direction = to_target_direction + hostile_noise * noise

            if %AttackTimer.is_stopped() and (attack_target.head.global_position.distance_to( %Core.global_position) < attack_begin_distance):
                burst_attack()

    desired_direction = lerp(desired_direction, next_direction, delta * air_accel)

    movement_velocity = desired_direction * speed


func burst_attack() -> void :
    if dead or disabled:
        return
    %AttackTimer.start()
    %AttackAnimationPlayer.play("burst")


func preserve_save(file: SaveFile, uuid: String) -> void :
    super.preserve_save(file, uuid)
    file.set_data("node/%s/model/variant" % uuid, variant)
    file.set_data("node/%s/anger" % uuid, anger)


func preserve_load(file: SaveFile, uuid: String) -> void :
    super.preserve_load(file, uuid)
    variant = file.get_data("node/%s/model/variant" % uuid, randi_range(1, len(core_models)))
    anger = file.get_data("node/%s/anger" % uuid, 0)
