class_name Yhvh extends Entity

@export var comet_scene: PackedScene
@export var summon_scene: PackedScene
@export var bolt_scene: PackedScene
@export var scary_time_scale: float = 1.3
@export var final_time_scale: float = 1.6

@export var thresholds: Array[float]

@export var calm_speed: float = 2.0
@export var calm_arm_speed: float = 8.0
@export var fight_speed: float = 3.0
@export var fight_arm_speed: float = 3.0
@export var fight_distance: float = 6.0
@export var hover_height: float = 6.0

@export var comet_time_min: float = 1.0
@export var comet_time_max: float = 3.0
@export var comet_radius: float = 64.0
@export var comet_height: float = 64.0

@export var laser_warning_max_distance: float = 64.0

@export var arm_attack_time_min: float = 5.0
@export var arm_attack_time_max: float = 7.0
@export var arm_damage: int = 6
@export var arm_knockback_strength: float = 32

@export var laser_time_min: float = 5.0
@export var laser_time_max: float = 7.0

@export var spawn_time_min: float = 5.0
@export var spawn_time_max: float = 7.0
@export var spawn_radius: float = 48.0

@onready var arm_controller: Node3D = %ArmController

signal laser_done(success: bool)

enum {CALM_STORM, FIGHT, SCARY_STORM, SCARY_FIGHT, FINAL_FIGHT}

var state: int = CALM_STORM

var arm_hitbox: bool = false
var arm_movement_velocity: Vector3
var target_arm_velocity: Vector3
var target_arm_look_direction: Vector3
var target_velocity: Vector3
var target_look_direction: Vector3
var laser_position: Vector3
var shooting_laser: bool = false

var look_direction: Vector3:
    set(val):
        look_direction = val
        SpatialMath.look_at_local(rotation_pivot, look_direction.normalized())
var arm_look_direction: Vector3:
    set(val):
        arm_look_direction = val
        SpatialMath.look_at_local(arm_controller, arm_look_direction.normalized())

func _ready() -> void :
    super._ready()
    remove_from_group("preserve_but_delete_on_unload")

    health_changed.connect(_on_health_changed)

    disabled = false

    %CometTimer.timeout.connect(_on_comet_timeout)
    %CometTimer.start(5.0 + randf_range(comet_time_min, comet_time_max) * get_attack_time_scale())
    %ArmTimer.timeout.connect(_on_arm_attack_timeout)
    %ArmTimer.start(randf_range(arm_attack_time_min, arm_attack_time_max) * get_attack_time_scale())
    %LaserTimer.timeout.connect(_on_laser_timeout)
    %LaserTimer.start(3.0 + randf_range(laser_time_min, laser_time_max) * get_attack_time_scale())
    %SpawnTimer.timeout.connect(_on_spawn_timeout)
    %SpawnTimer.start(3.0 + randf_range(spawn_time_min, spawn_time_max) * get_attack_time_scale())

    modulate_changed.connect(_on_modulate_changed)
    alpha_changed.connect(_on_alpha_changed)

    global_position = Vector3(0, 4, -16)
    look_direction = Vector3(0, 0, -1)

    target_look_direction = look_direction
    target_velocity = look_direction * calm_speed

    arm_controller.global_position = %ArmIdle.global_position
    target_arm_velocity = Vector3()

    arm_look_direction = look_direction
    target_arm_look_direction = arm_look_direction

    %ArmAttackArea3D.area_entered.connect(_on_area_entered_attack)
    %ArmAttackArea3D.body_entered.connect(_on_body_entered_attack)

    %ArmAnimationPlayer.play("RESET")
    %LaserAnimationPlayer.play("RESET")

func _on_area_entered_attack(area: Area3D) -> void :
    _attack_arm_target(_resolve_arm_attack_target(area))


func _on_body_entered_attack(body: Node3D) -> void :
    _attack_arm_target(_resolve_arm_attack_target(body))


func _resolve_arm_attack_target(hit_object):
    if not is_instance_valid(hit_object):
        return null
    if hit_object is Area3D:
        if is_instance_valid(hit_object.owner):
            return hit_object.owner
        if is_instance_valid(hit_object.get_parent()):
            return hit_object.get_parent()
    return hit_object if hit_object is Node3D else null


func _attack_arm_target(target) -> void :
    if not arm_hitbox or dead or disabled or not is_instance_valid(target) or not is_inside_tree() or not has_node("%ArmTarget"):
        return
    if not (target is Entity or is_session_player_entity(target)):
        return
    if target == self or target.disabled or target.dead or target.direct_damage_cooldown:
        return

    var actual_damage: int = int(arm_damage)
    if is_session_player_entity(target) and target != Ref.player:
        if target.has_method("begin_direct_damage_cooldown"):
            target.begin_direct_damage_cooldown()
        else:
            target.direct_damage_cooldown = true
        if Ref.coop_manager.sync_host_attack_on_remote_player(self, target, target.global_position, actual_damage, arm_knockback_strength, 1.0, false):
            %AttackCooldown.start()
        return

    var knockback_velocity: Vector3 = Ref.coop_manager.calculate_attack_knockback_velocity(target, %ArmTarget.global_position, arm_movement_velocity, arm_knockback_strength, 1.0) if Ref.coop_manager != null else Vector3.ZERO
    target.knockback_velocity += knockback_velocity
    target.attacked(self, actual_damage)


    if target.held_item != null and target.held_item.item is Tool:
        target.decrease_held_item_durability(1)

    if target.has_node("%Bleed"):
        var target_to_attacker = (global_position - target.global_position).normalized()
        target.get_node("%Bleed").bleed(target.head.global_position, target_to_attacker, actual_damage)

    %AttackCooldown.start()

func _on_health_changed(_health: int) -> void :
    var percentage: float = clamp(health / float(max_health), 0.0, 1.0)
    if state == CALM_STORM and percentage < thresholds[0]:
        state = FIGHT
    if state == FIGHT and percentage < thresholds[1]:
        state = SCARY_STORM
    if state == SCARY_STORM and percentage < thresholds[2]:
        state = SCARY_FIGHT
    if state == SCARY_FIGHT and percentage < thresholds[3]:
        state = FINAL_FIGHT
    %Fractal.material_override.set_shader_parameter("fractal_color_2", Color(percentage, percentage, percentage))
    %Arm.material_override.set_shader_parameter("fractal_color_2", Color(percentage, percentage, percentage))
    %ScreamSound.enabled = percentage < thresholds[3]




func _on_modulate_changed(new_modulate: Color) -> void :
    %Fractal.set("instance_shader_parameters/albedo", new_modulate)
    %Arm.set("instance_shader_parameters/albedo", new_modulate)
    %Wings.model.set("instance_shader_parameters/albedo", new_modulate)

func _on_alpha_changed(new_alpha: float) -> void :
    %Fractal.set("instance_shader_parameters/fade", new_alpha)
    %Arm.set("instance_shader_parameters/fade", new_alpha)
    %Wings.model.set("instance_shader_parameters/fade", new_alpha)




func _on_comet_timeout() -> void :
    if not is_inside_tree() or not has_node("%CometTimer"):
        return
    %CometTimer.start(randf_range(comet_time_min, comet_time_max) * get_attack_time_scale())
    if not (state == CALM_STORM or state == SCARY_STORM) or dead or disabled:
        return
    var offset: Vector3 = randf_range(0, comet_radius) * Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() + Vector3(0, comet_height, 0)
    var direction: Vector3 = Vector3(randf_range(-1, 1), -6, randf_range(-1, 1)).normalized()
    var new_comet: Comet = comet_scene.instantiate()
    get_tree().get_root().add_child(new_comet)
    new_comet.entity_owner = self
    new_comet.shoot(offset + get_session_target_entity_position(global_position, Ref.player), direction)



func _on_spawn_timeout() -> void :
    if not is_inside_tree() or not has_node("%SpawnTimer"):
        return
    %SpawnTimer.start(3.0 + randf_range(spawn_time_min, spawn_time_max) * get_attack_time_scale())
    if not (state == SCARY_FIGHT or state == SCARY_STORM or state == FINAL_FIGHT) or dead or disabled:
        return
    var offset: Vector3 = randf_range(0, spawn_radius) * Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() + Vector3(0, comet_height, 0)
    %SpawnCheck.global_position = offset + get_session_target_entity_position(global_position, Ref.player)
    %SpawnCheck.target_position = Vector3(0, -96, 0)
    if not %SpawnCheck.is_colliding():
        return

    var new_summon: ArchangelSummon = summon_scene.instantiate()
    get_tree().get_root().add_child(new_summon)
    new_summon.summon( %SpawnCheck.get_collision_point())

func update_laser() -> void :
    if not is_inside_tree() or not has_node("%Laser") or not has_node("%HitCast"):
        return
    var direction: Vector3 = %Laser.global_position.direction_to(laser_position)
    %HitCast.target_position = Vector3(0, 0, - laser_warning_max_distance)
    SpatialMath.look_at_local( %HitCast, direction)
    %HitCast.force_raycast_update()
    if not %HitCast.is_colliding():
        laser_done.emit(false)
        shooting_laser = false
        return
    laser_position = %HitCast.get_collision_point()
    update_laser_visual()

func update_laser_visual() -> void :
    if not is_inside_tree() or not has_node("%BeamIndicator"):
        return
    SpatialMath.look_at( %BeamIndicator, laser_position)
    %BeamIndicator.scale.z = global_position.distance_to(laser_position) * 2.0

func _on_laser_timeout() -> void :
    if not is_inside_tree() or not has_node("%HitCast") or not has_node("%Laser") or not has_node("%LaserAnimationPlayer"):
        return
    %LaserTimer.start(randf_range(laser_time_min, laser_time_max) * get_attack_time_scale())
    if state == CALM_STORM or dead or disabled or shooting_laser:
        return
    var general_direction: Vector3 = (%Laser.global_position.direction_to(get_session_target_entity_head_position(%Laser.global_position + Vector3(0, 1.45, 0), Ref.player)) + 0.1 * Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))).normalized()
    %HitCast.target_position = Vector3(0, 0, - laser_warning_max_distance)
    SpatialMath.look_at_local( %HitCast, general_direction)
    %HitCast.force_raycast_update()
    if not %HitCast.is_colliding():
        return
    shooting_laser = true
    laser_position = %HitCast.get_collision_point()
    update_laser_visual()
    %LaserAnimationPlayer.play("shoot")
    var success: bool = await laser_done
    if success:
        var new_bolt: Bolt = bolt_scene.instantiate()
        get_tree().get_root().add_child(new_bolt)
        new_bolt.global_position = %Laser.global_position
        new_bolt.entity_owner = self
        new_bolt.fire( %Laser.global_position.direction_to(laser_position), true)
    %LaserAnimationPlayer.stop()
    shooting_laser = false

func _on_arm_attack_timeout() -> void :
    if not is_inside_tree() or not has_node("%ArmTimer") or not has_node("%ArmAnimationPlayer"):
        return
    arm_hitbox = false
    %ArmTimer.start(randf_range(arm_attack_time_min, arm_attack_time_max) * get_attack_time_scale())
    if not (state == FIGHT or state == SCARY_FIGHT or state == FINAL_FIGHT) or dead or disabled:
        return
    %ArmAnimationPlayer.play("thrust")

func _process(_delta: float) -> void :
    pass

func _physics_process(delta: float) -> void :
    if disabled:
        return

    if shooting_laser:
        update_laser()
    var speed_multiplier: float = 1.0
    if state == SCARY_STORM or state == SCARY_FIGHT:
        speed_multiplier = 1.6

    if state == CALM_STORM or state == SCARY_STORM:
        target_look_direction = Vector3(0, 0, -1)
        target_velocity = target_look_direction * calm_speed * speed_multiplier
        if global_position.y < 4:
            target_velocity.y = 1
        target_arm_look_direction = target_look_direction
        target_arm_velocity = %ArmTarget.global_position.direction_to( %ArmIdle.global_position) * calm_arm_speed
    if state == FIGHT or state == SCARY_FIGHT or state == FINAL_FIGHT:
        var player_head: Vector3 = get_session_target_entity_head_position(%Laser.global_position + Vector3(0, 1.45, 0), Ref.player)
        var to_player: Vector3 = player_head - head.global_position
        var horizontal_offset: Vector3 = Vector3(to_player.x, 0, to_player.z)
        var horizontal_distance: float = horizontal_offset.length()
        var desired_pos: Vector3 = player_head + Vector3(0, hover_height, 0)
        if horizontal_distance > fight_distance:
            target_velocity.x = horizontal_offset.normalized().x * fight_speed * speed_multiplier
            target_velocity.z = horizontal_offset.normalized().z * fight_speed * speed_multiplier
        else:
            target_velocity.x = - horizontal_offset.normalized().x * fight_speed * 1.2 * speed_multiplier
            target_velocity.z = - horizontal_offset.normalized().z * fight_speed * 1.2 * speed_multiplier
        var height_error: float = desired_pos.y - head.global_position.y
        target_velocity.y = height_error * 2.5
        target_look_direction = (player_head - head.global_position).normalized()


        var arm_controller_pos: Vector3 = %ArmController.global_position

        var arm_hover_height: float = 0.6
        var arm_fight_distance: float = 0.8

        var desired_arm_pos: Vector3 = player_head + Vector3(0, arm_hover_height, 0)
        var to_arm_target: Vector3 = desired_arm_pos - arm_controller_pos

        var arm_horizontal_offset: Vector3 = Vector3(to_arm_target.x, 0, to_arm_target.z)
        var arm_horizontal_distance: float = arm_horizontal_offset.length()

        if arm_horizontal_distance > arm_fight_distance:
            target_arm_velocity.x = arm_horizontal_offset.normalized().x * fight_arm_speed * speed_multiplier
            target_arm_velocity.z = arm_horizontal_offset.normalized().z * fight_arm_speed * speed_multiplier
        else:
            target_arm_velocity.x = - arm_horizontal_offset.normalized().x * fight_arm_speed * 1.1 * speed_multiplier
            target_arm_velocity.z = - arm_horizontal_offset.normalized().z * fight_arm_speed * 1.1 * speed_multiplier

        var arm_height_error: = desired_arm_pos.y - arm_controller_pos.y
        target_arm_velocity.y = arm_height_error * 2.0


        target_arm_look_direction = (player_head - arm_controller_pos).normalized()

    arm_look_direction = lerp(arm_look_direction, target_arm_look_direction, clamp(0.16 * delta, 0.0, 1.0))
    arm_movement_velocity = lerp(arm_movement_velocity, target_arm_velocity, clamp(0.5 * delta, 0.0, 1.0))

    look_direction = lerp(look_direction, target_look_direction, clamp(delta, 0.0, 1.0))
    movement_velocity = lerp(movement_velocity, target_velocity, clamp(0.5 * delta, 0.0, 1.0))

    global_position += movement_velocity * delta + knockback_velocity * 0.35 * delta
    arm_controller.global_position += arm_movement_velocity * delta

    knockback_process(delta)

func get_attack_time_scale() -> float:
    if state == SCARY_FIGHT:
        return 1.0 / scary_time_scale
    if state == FINAL_FIGHT:
        return 1.0 / final_time_scale
    return 1.0

func enable_arm_hitbox() -> void :
    arm_hitbox = true

func disable_arm_hitbox() -> void :
    arm_hitbox = false

func die() -> void :
    if disabled or dead:
        return
    dead = true

    if not Ref.world.current_dimension == LucidBlocksWorld.Dimension.YHVH:
        queue_free()
        return

    Ref.game_menu.deactivate()
    get_tree().paused = true
    Ref.player.disabled = true

    %EarthquakePlayer.playing = true
    await Ref.trans.open_fade()
    await get_tree().create_timer(2.0, true).timeout

    queue_free()
    Ref.plot_manager.end_game()

func preserve_save(file: SaveFile, uuid: String) -> void :
    super.preserve_save(file, uuid)

    file.set_data("node/%s/arm_movement_velocity" % uuid, arm_movement_velocity)
    file.set_data("node/%s/target_arm_velocity" % uuid, target_arm_velocity)
    file.set_data("node/%s/target_arm_look_direction" % uuid, target_arm_look_direction)
    file.set_data("node/%s/target_velocity" % uuid, target_velocity)
    file.set_data("node/%s/target_look_direction" % uuid, target_look_direction)
    file.set_data("node/%s/arm_global_position" % uuid, arm_controller.global_position)

func preserve_load(file: SaveFile, uuid: String) -> void :
    super.preserve_load(file, uuid)

    arm_movement_velocity = file.get_data("node/%s/arm_movement_velocity" % uuid, arm_movement_velocity)
    target_arm_velocity = file.get_data("node/%s/target_arm_velocity" % uuid, target_arm_velocity)
    target_arm_look_direction = file.get_data("node/%s/target_arm_look_direction" % uuid, target_arm_look_direction)
    target_velocity = file.get_data("node/%s/target_velocity" % uuid, target_velocity)
    target_look_direction = file.get_data("node/%s/target_look_direction" % uuid, target_look_direction)
    arm_controller.global_position = file.get_data("node/%s/arm_global_position" % uuid, arm_controller.global_position)
