class_name Entity extends CharacterBody3D

@export_group("Stats")
@export var max_health: int = 10:
    set(val):
        max_health = val
        max_health_changed.emit(max_health)
        stats_updated.emit()

        if health == max_health and can_endure:
            has_endure = true
@export var weight: float = 1.0:
    get():
        return weight + weight_boost
@export var hate: int = 1:
    set(val):
        hate = val
        stats_updated.emit()
@export var lust: int = 1:
    set(val):
        lust = val
        stats_updated.emit()
@export var faith: int = 1:
    set(val):
        faith = val
        stats_updated.emit()
@export var druj: int = 1:
    set(val):
        druj = val
        stats_updated.emit()
@export var tiamana_drop: float = 0.2
@export var endure_threshold: int = 10
@export var can_endure: bool = false
@export var pickaxe_weakness: bool = false
@export var axe_weakness: bool = false
@export var cristella: bool = false
@export var slime: bool = false

@export_group("Movement")

@export var speed: float = 3.9
@export var knockback_resistance: float = 16.0

@export var ground_accel: float = 56.0

@export var air_accel: float = 48.0
@export var gravity: float = 32.0
@export var jump_impulse: float = 9
@export var jump_dampening: float = 16
@export var terminal_velocity: float = 53.0

@export_group("Water Movement")
@export var ascend_accel: float = 16.0
@export var ascend_speed: float = 2.6
@export var dive_speed: float = 1.5
@export var dive_accel: float = 12.0
@export var sink_speed: float = 3.0
@export var sink_accel: float = 32.0
@export var water_drag_accel: float = 0.2
@export var water_drag_speed: float = 0.45
@export var water_drag_jump: float = 0.35
@export var water_drag_gravity: float = 0.06

@export_group("Spawn")
@export var spawn_in_water: bool = false
@export var can_swarm: bool = false
@export var swarm_min: int = 1
@export var swarm_max: int = 3

@export_group("Loot")
@export var death_drop: Loot
@export var cooked_death_drop: Loot

var process_distance: float = 0.0:
    get:
        if _use_session_targeting():
            return Ref.coop_manager.get_same_instance_activity_radius()
        return Ref.world.instance_radius - 16

@export_group("Fire")

@export var fire_radius: float = 0.5

@export_group("Markers")
@export var head: Marker3D
@export var hand: Marker3D

@export_group("Inventory")

@export var held_item_inventory: Inventory
@export var equipment_inventory: Inventory

@export_group("Other")
@export var can_rename: bool = true
@export var disabled_by_visibility: bool = true
@export var damage_modulate: Color
@export var heal_modulate: Color
@export var dropped_item_scene: PackedScene
@export var modulate: Color = Color.WHITE:
    set(val):
        modulate = val
        total_modulate = modulate * 0.5 + modulate_mix * 0.5
@export var alpha: float = 1.0:
    set(val):
        alpha_changed.emit(val)
        alpha = val
@export var checks_for_water: bool = true

@onready var rotation_pivot: Node3D = %RotationPivot

enum {MELEE, FIRE, FALL, DROWN}

signal max_health_changed(max_health: int)
signal health_changed(health: int)
signal stats_updated

signal biome_changed(new_biome: Biome)
signal died
signal water_entered(vertical_velocity: float)
signal water_exited(vertical_velocity: float)
signal fire_entered
signal fire_exited
signal head_water_entered(vertical_velocity: float)
signal head_water_exited(vertical_velocity: float)
signal feet_water_entered(vertical_velocity: float)
signal feet_water_exited(vertical_velocity: float)
signal hit_ground(vertical_velocity: float)
signal on_attacked(attacker: Entity)
signal on_healed(healer: Entity)
signal damage_taken(damage: int)
signal held_item_index_changed
signal modulate_changed(new_modulate: Color)
signal alpha_changed(new_alpha: float)
signal death_drop_item


var held_item_index: int = 0:
    set(val):
        if held_item_index == val:
            return
        held_item_index = val
        held_item_index_changed.emit()
var held_item: HeldItem


var health: int = 0:
    set(val):
        health = max(val, 0)
        health_changed.emit(health)
        if health == max_health and can_endure:
            has_endure = true
        if health <= 0 and not dead:
            die()

var weight_boost: float = 0.0
var invincible: bool = false
var invincible_temporary: bool = false
var dead: bool = false:
    set(val):
        dead = val
        if dead:
            died.emit()
var direct_damage_cooldown: bool = false
var first_frame: bool = true
var wandering_spirit: bool = false


var movement_velocity: Vector3
var knockback_velocity: Vector3
var gravity_velocity: Vector3
var rope_velocity: Vector3
var rope_velocities: Dictionary[HeldRope, Vector3]
var residual_rope_velocity: Vector3

var movement_enabled: bool = true
var disabled: bool = true
var in_air: bool = false
var under_water: bool = false:
    set(val):
        if under_water != val or force_check_update:
            if val:
                water_entered.emit(velocity.y)
            else:
                water_exited.emit(velocity.y)
        under_water = val
var head_under_water: bool = false:
    set(val):
        if head_under_water != val or force_check_update:
            if val:
                head_water_entered.emit(velocity.y)
            else:
                head_water_exited.emit(velocity.y)
        head_under_water = val
var feet_under_water: bool = false:
    set(val):
        if feet_under_water != val or force_check_update:
            if val:
                feet_water_entered.emit(velocity.y)
            else:
                feet_water_exited.emit(velocity.y)
        feet_under_water = val
var touching_fire: bool = false:
    set(val):
        if touching_fire != val or force_check_update:
            if val:
                fire_entered.emit()
            else:
                fire_exited.emit()
        touching_fire = val
var buoyancy: float = 0.0
var last_velocity_y: float = 0.0
var current_biome: Biome = null


var water_speed_modifier: float = 1.0
var water_accel_modifier: float = 1.0
var water_jump_modifier: float = 1.0
var water_gravity_modifier: float = 1.0


var static_water_speed_modifier: float = 1.0
var static_speed_modifier: float = 1.0
var glider_speed_modifier: float = 1.0
var static_accel_modifier: float = 1.0
var static_jump_modifier: float = 1.0
var biome_jump_modifier: float = 1.0
var gravity_direction_multiplier: float = 1.0
var static_gravity_modifier: float = 1.0
var glider_gravity_modifier: float = 1.0
var biome_gravity_modifier: float = 1.0
var air_accel_modifier: float = 1.0
var slip_accel_modifier: float = 1.0
var boost_speed_modifier: float = 1.0
var swarming: bool = false
var force_check_update: bool = true

var nickname: String = "":
    set(val):

        if nickname != "" and val == "":
            remove_from_group("preserve")
            add_to_group("preserve_but_delete_on_unload")


        if nickname == "" and val != "":
            add_to_group("preserve")
            remove_from_group("preserve_but_delete_on_unload")

        nickname = val
        %NameTag.visible = nickname != ""
        %NameTag.text = nickname


var modulate_mix: Color = Color.WHITE:
    set(val):
        modulate_mix = val
        total_modulate = modulate * 0.5 + modulate_mix * 0.5
var total_modulate: Color = Color.WHITE:
    set(val):
        total_modulate = val
        modulate_changed.emit(total_modulate)

var modulate_tween: Tween

var speed_modifier: float:
    get():
        return water_speed_modifier * static_speed_modifier * glider_speed_modifier * boost_speed_modifier

var accel_modifier: float:
    get():
        return water_accel_modifier * static_accel_modifier / slip_accel_modifier

var jump_modifier: float:
    get():
        return water_jump_modifier * static_jump_modifier

var gravity_modifier: float:
    get():
        return biome_gravity_modifier * water_gravity_modifier * static_gravity_modifier * glider_gravity_modifier

var last_attacker: Entity

var has_endure: bool = false

func _ready() -> void :
    if swarming:
        var count: int = randi_range(swarm_min, swarm_max)
        for i in range(count):
            var new_position: Vector3 = global_position + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
            if not is_session_position_loaded(new_position) or Ref.world.is_block_solid_at(new_position):
                continue

            var new_entity: Entity = self.duplicate()
            get_parent().add_child(new_entity)
            new_entity.global_position = new_position
    swarming = false

    _refresh_visibility_enabler_target()

    health = max_health
    assert (is_instance_valid(hand))
    assert (is_instance_valid(head))

    held_item_inventory.item_slot_changed.connect(_on_held_item_inventory_item_slot_changed)
    equipment_inventory.item_slot_changed.connect(_on_equipment_inventory_item_slot_changed)

    %DirectDamageTimer.timeout.connect(_on_damage_timeout)
    %DistanceCheckTimer.timeout.connect(_on_distance_check_timeout)
    %DistanceCheckTimer.start()

func _on_instant_interact_impulse() -> void :
    pass


func _on_distance_check_timeout() -> void :
    _refresh_visibility_enabler_target()
    distance_process_check()


func _use_session_targeting() -> bool:
    return multiplayer.is_server() and Ref.coop_manager != null and Ref.coop_manager.has_connected_remote_peers()


func _should_ignore_visibility_culling() -> bool:
    return _use_session_targeting()


func _can_use_session_load_proxy() -> bool:
    return _use_session_targeting() \
        and Ref.coop_manager != null \
        and Ref.coop_manager.has_method("can_use_same_instance_load_proxies") \
        and bool(Ref.coop_manager.call("can_use_same_instance_load_proxies"))


func _refresh_visibility_enabler_target() -> void:
    if _should_ignore_visibility_culling() or not disabled_by_visibility:
        %VisibleOnScreenEnabler3D.enable_node_path = ""
        %VisibleOnScreenEnabler3D.process_mode = Node.PROCESS_MODE_DISABLED if _should_ignore_visibility_culling() else Node.PROCESS_MODE_INHERIT
        disabled = false
    else:
        %VisibleOnScreenEnabler3D.process_mode = Node.PROCESS_MODE_INHERIT
        %VisibleOnScreenEnabler3D.enable_node_path = ".."


func is_session_position_loaded(world_position: Vector3) -> bool:
    if Ref.world.is_position_loaded(world_position):
        return true
    return _can_use_session_load_proxy() and Ref.coop_manager.is_position_near_same_instance_player(world_position, process_distance)


func is_session_player_entity(entity) -> bool:
    return is_instance_valid(entity) and (entity == Ref.player or (_use_session_targeting() and Ref.coop_manager.is_remote_player_proxy(entity)))


func get_session_target_entity(default_target = null):
    var fallback = default_target
    if not is_instance_valid(fallback) and is_instance_valid(Ref.player):
        fallback = Ref.player
    if not _use_session_targeting():
        return fallback
    return Ref.coop_manager.get_preferred_session_player_entity(global_position, fallback, fallback)


func get_session_target_position(default_position: Vector3) -> Vector3:
    if not _use_session_targeting():
        return default_position
    return Ref.coop_manager.get_nearest_session_player_position(global_position, default_position)


func get_session_target_head_position(default_position: Vector3) -> Vector3:
    if not _use_session_targeting():
        return default_position
    return Ref.coop_manager.get_nearest_session_player_head_position(global_position, default_position)


func is_session_target_within(radius: float) -> bool:
    return _use_session_targeting() and Ref.coop_manager.is_position_near_same_instance_player(global_position, radius)


func _on_damage_timeout() -> void :
    direct_damage_cooldown = false


func _on_held_item_inventory_item_slot_changed(_inventory: Inventory, index: int) -> void :
    if index == held_item_index:
        _refresh_held_item_from_inventory_slot(index)


func _on_equipment_inventory_item_slot_changed(_inventory: Inventory, _index: int) -> void :
    equip_equipment()


func _physics_process(delta: float) -> void :
    if disabled:
        return

    _on_distance_check_timeout()

    up_direction = Vector3(0, gravity_direction_multiplier, 0)
    rotation_degrees = Vector3(180 if gravity_direction_multiplier < 0 else 0, 0, 0)

    velocity = movement_velocity + knockback_velocity + gravity_velocity + rope_velocity

    update_biome()
    check_fire()
    if checks_for_water:
        check_water()

    if first_frame:
        first_frame = false
        return


    if is_session_position_loaded(%CenterPoint.global_position) and Ref.world.is_block_solid_at(%CenterPoint.global_position):
        global_position.y += 1.0

    if not is_on_floor():
        in_air = true
    if in_air and is_on_floor():
        in_air = false
        hit_ground.emit(last_velocity_y)

    gravity_process(delta)
    water_physics_process(delta)
    knockback_process(delta)
    rope_process(delta)

    last_velocity_y = velocity.y

    if gravity_direction_multiplier * velocity.y < - terminal_velocity:
        velocity.y = - gravity_direction_multiplier * terminal_velocity

    force_check_update = false


func knockback_process(delta: float) -> void :
    var resist_measure: float = Vector3(movement_velocity.x, 0.0, movement_velocity.z).dot(Vector3(knockback_velocity.x, 0.0, knockback_velocity.z))
    var knockback_movement_cancel: float = (2.0 + 0.2 / accel_modifier) if resist_measure < -0.1 else 1.0
    knockback_movement_cancel = lerp(knockback_movement_cancel, 1.0, Vector3(knockback_velocity.x, 0.0, knockback_velocity.z).length() / 32.0)
    knockback_velocity.y = lerp(knockback_velocity.y, 0.0, clamp(delta * knockback_movement_cancel * knockback_resistance, 0.0, 1.0))
    knockback_velocity.x = lerp(knockback_velocity.x, 0.0, clamp(delta * knockback_movement_cancel * knockback_resistance * accel_modifier, 0.0, 1.0))
    knockback_velocity.z = lerp(knockback_velocity.z, 0.0, clamp(delta * knockback_movement_cancel * knockback_resistance * accel_modifier, 0.0, 1.0))


func gravity_process(delta: float) -> void :
    if is_on_floor():
        gravity_velocity.y = -1.0 * gravity_direction_multiplier
    else:
        gravity_velocity.y -= delta * gravity * gravity_modifier * gravity_direction_multiplier


func rope_process(delta: float) -> void :
    var resist_measure: float = Vector3(movement_velocity.x, 0.0, movement_velocity.z).dot(Vector3(residual_rope_velocity.x, 0.0, residual_rope_velocity.z))
    var rope_movement_cancel: float = (2.0 + 0.2 / accel_modifier) if resist_measure < -0.1 else 1.0
    rope_movement_cancel = lerp(rope_movement_cancel, 1.0, Vector3(residual_rope_velocity.x, 0.0, residual_rope_velocity.z).length() / 32.0)
    residual_rope_velocity.y = lerp(residual_rope_velocity.y, 0.0, clamp(delta * 8.0, 0.0, 1.0))
    residual_rope_velocity.x = lerp(residual_rope_velocity.x, 0.0, clamp(delta * 12.0 * rope_movement_cancel * accel_modifier, 0.0, 1.0))
    residual_rope_velocity.z = lerp(residual_rope_velocity.z, 0.0, clamp(delta * 12.0 * rope_movement_cancel * accel_modifier, 0.0, 1.0))

    rope_velocity = residual_rope_velocity

    for rope in rope_velocities:
        rope_velocity += rope_velocities[rope]


func water_physics_process(delta: float) -> void :
    if under_water:
        buoyancy += 2.0 * delta / 0.25
        if gravity_velocity.y * gravity_direction_multiplier < - sink_speed:
            gravity_velocity.y += delta * sink_accel * gravity_direction_multiplier
    else:
        buoyancy -= 2.0 * delta / 0.25
    buoyancy = clamp(buoyancy, 0.0, 1.0)

    water_accel_modifier = lerp(1.0, water_drag_accel, buoyancy)
    water_jump_modifier = lerp(1.0, water_drag_jump, buoyancy)
    water_speed_modifier = lerp(1.0, water_drag_speed * static_water_speed_modifier, buoyancy)
    water_gravity_modifier = lerp(1.0, clamp(water_drag_gravity * 1.3 * (1.0 + weight_boost), 0.0, 0.86), buoyancy)


func default_entity_movement(delta: float, movement_direction: Vector3, horizontal_accel: float, walk_speed: float, jump: bool, swim_up: bool, swim_down: bool) -> bool:
    var jumped: bool = false
    var vertical_movement_velocity: float = movement_velocity.y
    movement_velocity = lerp(movement_velocity, movement_direction * walk_speed, min(1.0, delta * horizontal_accel * (0.5 if slip_accel_modifier > 1.0 else 1.0)))
    movement_velocity.y = vertical_movement_velocity

    if not under_water:
        movement_velocity.y -= delta * jump_dampening * gravity_direction_multiplier
        if gravity_direction_multiplier * movement_velocity.y < 0 or is_on_floor():
            movement_velocity.y = 0
    else:
        if swim_up and (gravity_direction_multiplier * movement_velocity.y < static_water_speed_modifier * ascend_speed) and buoyancy > 0.8:
            movement_velocity.y += gravity_direction_multiplier * ascend_accel * delta
        elif swim_down and gravity_direction_multiplier * movement_velocity.y > - dive_speed:
            movement_velocity.y -= gravity_direction_multiplier * dive_accel * delta
        else:
            movement_velocity.y = lerp(movement_velocity.y, 0.0, clamp(delta, 0.0, 1.0))
    if is_on_floor() and jump:
        jumped = true
        movement_velocity.y = (jump_modifier * jump_impulse * biome_jump_modifier * gravity_direction_multiplier)
    if is_on_ceiling() and gravity_direction_multiplier * gravity_velocity.y > 0:
        gravity_velocity.y = 0
    if jumped:
        %JumpSound.play()

    return jumped


func check_water() -> void :
    head_under_water = (is_session_position_loaded(head.global_position) and Ref.world.is_under_water(head.global_position))
    under_water = (is_session_position_loaded(%CenterPoint.global_position) and Ref.world.is_under_water(%CenterPoint.global_position))
    feet_under_water = (is_session_position_loaded(global_position + gravity_direction_multiplier * Vector3(0, 0.05, 0)) and Ref.world.is_under_water(global_position + gravity_direction_multiplier * Vector3(0, 0.05, 0)))


func check_fire() -> void :
    var on_fire_check: bool = false

    var fire_vec: Vector3 = %CenterPoint.global_position + fire_radius * Vector3(1, 0, 0)
    on_fire_check = (on_fire_check or (is_session_position_loaded(fire_vec) and Ref.world.get_fire_at(fire_vec) > 0))

    fire_vec = %CenterPoint.global_position + fire_radius * Vector3(-1, 0, 0)
    on_fire_check = (on_fire_check or (is_session_position_loaded(fire_vec) and Ref.world.get_fire_at(fire_vec) > 0))

    fire_vec = %CenterPoint.global_position + fire_radius * Vector3(0, 0, 1)
    on_fire_check = (on_fire_check or (is_session_position_loaded(fire_vec) and Ref.world.get_fire_at(fire_vec) > 0))

    fire_vec = %CenterPoint.global_position + fire_radius * Vector3(0, 0, -1)
    on_fire_check = (on_fire_check or (is_session_position_loaded(fire_vec) and Ref.world.get_fire_at(fire_vec) > 0))

    fire_vec = %CenterPoint.global_position + fire_radius * Vector3(0, -1, 0)
    on_fire_check = (on_fire_check or (is_session_position_loaded(fire_vec) and Ref.world.get_fire_at(fire_vec) > 0))

    touching_fire = on_fire_check





func attacked(attacker: Entity, damage: int) -> void :
    if dead or disabled:
        return

    direct_damage_cooldown = true
    %DirectDamageTimer.start()

    if damage < 0:
        on_healed.emit(attacker)
        heal( - damage)
    else:
        on_attacked.emit(attacker)
        take_damage(damage, MELEE)
        last_attacker = attacker


func heal(heal_power: int) -> void :
    if invincible or dead or disabled:
        return

    if health < max_health:
        %HealSound.play()

    health = min(max_health, heal_power + health)

    if is_instance_valid(modulate_tween) and modulate_tween.is_running():
        modulate_tween.stop()

    if not dead:
        modulate_tween = get_tree().create_tween()
        modulate_tween.tween_property(self, "modulate", heal_modulate, 0.04)
        await get_tree().create_timer(0.25, false).timeout
        modulate_tween = get_tree().create_tween()
        modulate_tween.tween_property(self, "modulate", Color.WHITE, 0.07)


func take_damage(damage: int, type: int) -> void :
    if invincible or invincible_temporary:
        return

    health = min(health, max_health)
    if dead or disabled:
        return

    var endure_damage: int = health - 1
    if has_endure and health > 1 and damage >= health and damage < endure_threshold:
        print("Endured death!")
        has_endure = false
        damage = endure_damage

    health -= damage
    damage_taken.emit(damage)

    var equipment_damage: bool = false

    match type:
        MELEE:
            equipment_damage = true
            if randf() < 0.1:
                %FallSound.play()
            %ImpactSound.play()
        DROWN:
            %ImpactSound.play()
        FALL:
            equipment_damage = true
            %FallSound.play()
            %ImpactSound.play()
        FIRE:
            equipment_damage = true
            %ImpactSound.play()
            %BurnSound.play()

    if equipment_damage:
        damage_equipment(damage)

    if is_instance_valid(modulate_tween) and modulate_tween.is_running():
        modulate_tween.stop()

    if not dead:
        modulate_tween = get_tree().create_tween()
        modulate_tween.tween_property(self, "modulate", damage_modulate, 0.04)
        await get_tree().create_timer(0.25, false).timeout
        modulate_tween = get_tree().create_tween()
        modulate_tween.tween_property(self, "modulate", Color.WHITE, 0.07)


func damage_equipment(damage: int, index: int = -1) -> void :
    if not is_instance_valid(equipment_inventory):
        return
    for i in range(len(equipment_inventory.items)):
        var item_state: ItemState = equipment_inventory.items[i]
        if item_state != null and (index == -1 or index == i):
            equipment_inventory.decrease_item_durability(i, damage)


func die() -> void :
    if disabled or dead:
        return
    if is_instance_valid(held_item):
        held_item.interact_end()
    dead = true

    if last_attacker == Ref.player:
        Ref.player.get_node("%Level").give_tiamana(tiamana_drop, Level.TiamanaSource.CUTSCENE)


    remove_from_group("preserve_but_delete_on_unload")
    remove_from_group("preserve_but_delete_on_unload")
    add_to_group("delete_on_quit")

    for child in %InteractArea3D.get_children():
        if child is CollisionShape3D:
            child.disabled = true
    %DeathAnimationPlayer.play("die")

    await death_drop_item
    var items: Array[ItemState]
    if cooked_death_drop != null and has_node("%Burn") and (get_node("%Burn").burning or get_node("%Burn").died_while_burning):
        items = cooked_death_drop.realize()
    elif death_drop != null:
        items = death_drop.realize()

    items.append_array( %Inventory.items)
    for item in items:
        if item == null:
            continue
        var new_item: DroppedItem = dropped_item_scene.instantiate()
        get_tree().get_root().add_child(new_item)
        new_item.global_position = (Vector3(0.05, 0.05, 0) + %CenterRotatePoint.global_position - Vector3(0.5, 0.5, 0.5))
        new_item.delay_merge()
        new_item.initialize(item)
    await %DeathAnimationPlayer.animation_finished

    queue_free()



func update_biome() -> void :
    var biome: Biome = Ref.world.generator.get_biome_at_real(global_position)
    if biome != current_biome:
        current_biome = biome
        biome_changed.emit(current_biome)
    biome_gravity_modifier = biome.gravity_scale
    biome_jump_modifier = lerp(1.3, 1.0, biome.gravity_scale)





func preserve_save(file: SaveFile, uuid: String) -> void :
    var multidimensional: bool = uuid == "player"

    file.set_data("node/%s/held_item_index" % uuid, held_item_index, multidimensional)


    unhold_item()
    unequip_equipment()

    file.set_data("node/%s/in_air" % uuid, in_air, false)
    file.set_data("node/%s/global_position" % uuid, global_position, false)
    file.set_data("node/%s/movement_velocity" % uuid, movement_velocity, false)
    file.set_data("node/%s/gravity_velocity" % uuid, gravity_velocity, false)
    file.set_data("node/%s/knockback_velocity" % uuid, knockback_velocity, false)
    file.set_data("node/%s/rope_velocity" % uuid, rope_velocity, false)
    file.set_data("node/%s/health" % uuid, health, multidimensional)
    file.set_data("node/%s/max_health" % uuid, max_health, multidimensional)
    file.set_data("node/%s/hate" % uuid, hate, multidimensional)
    file.set_data("node/%s/faith" % uuid, faith, multidimensional)
    file.set_data("node/%s/lust" % uuid, lust, multidimensional)
    file.set_data("node/%s/rotation_pivot" % uuid, %RotationPivot.rotation.y, false)
    file.set_data("node/%s/nickname" % uuid, nickname, multidimensional)
    file.set_data("node/%s/has_endure" % uuid, has_endure, multidimensional)

    for child in find_children("*"):
        if "preserve_save" in child:
            child.preserve_save(file, uuid)


    equip_equipment()
    hold_item(held_item_index)


func preserve_load(file: SaveFile, uuid: String) -> void :
    var multidimensional: bool = uuid == "player"

    unhold_item()
    unequip_equipment()

    global_position = file.get_data("node/%s/global_position" % uuid, Vector3(), false)

    in_air = file.get_data("node/%s/in_air" % uuid, false)
    movement_velocity = file.get_data("node/%s/movement_velocity" % uuid, Vector3(), false)
    gravity_velocity = file.get_data("node/%s/gravity_velocity" % uuid, Vector3(), false)
    knockback_velocity = file.get_data("node/%s/knockback_velocity" % uuid, Vector3(), false)
    rope_velocity = file.get_data("node/%s/rope_velocity" % uuid, Vector3(), false)
    nickname = file.get_data("node/%s/nickname" % uuid, "", multidimensional)
    has_endure = file.get_data("node/%s/has_endure" % uuid, can_endure, multidimensional)

    %RotationPivot.rotation.y = file.get_data("node/%s/rotation_pivot" % uuid, %RotationPivot.rotation.y, false)
    max_health = file.get_data("node/%s/max_health" % uuid, max_health, multidimensional)
    hate = file.get_data("node/%s/hate" % uuid, hate, multidimensional)
    faith = file.get_data("node/%s/faith" % uuid, faith, multidimensional)
    lust = file.get_data("node/%s/lust" % uuid, lust, multidimensional)
    health = file.get_data("node/%s/health" % uuid, max_health, multidimensional)
    held_item_index = file.get_data("node/%s/held_item_index" % uuid, 0, multidimensional)

    for child in find_children("*"):
        if "preserve_load" in child:
            child.preserve_load(file, uuid)

    equip_equipment()
    hold_item(held_item_index)





func decrease_held_item_durability(amount: int) -> void :
    if held_item == null:
        return
    held_item_inventory.decrease_item_durability(held_item_index, amount)


func _refresh_held_item_from_inventory_slot(index: int) -> void:
    hold_item(index)



func hold_item(index: int) -> void :
    held_item_index = index

    unhold_item()

    if held_item_inventory.items[index] == null:
        return

    var item_state: ItemState = held_item_inventory.items[index]
    var item: Item = ItemMap.map(item_state.id)

    var held_item_scene: PackedScene = item.held_item_scene
    if held_item_scene == null:
        return
    held_item = held_item_scene.instantiate()
    held_item.instant_interact_impulse.connect(_on_instant_interact_impulse)

    hand.add_child(held_item)
    held_item.initialize(held_item_inventory, held_item_index, self)
    held_item.on_hold()


func unhold_item() -> void :
    if is_instance_valid(held_item):
        held_item.interact_end()
        held_item.on_unhold()
        held_item.queue_free()
    held_item = null



func equip_equipment() -> void :
    unequip_equipment()
    for index in range(equipment_inventory.capacity):
        var item_state: ItemState = equipment_inventory.items[index]
        if item_state == null:
            continue
        var equipment_item: HeldItem = ItemMap.map(item_state.id).held_item_scene.instantiate()
        %EquipmentHolder.add_child(equipment_item)
        equipment_item.initialize(equipment_inventory, index, self)
        equipment_item.on_equip()
    health = min(health, max_health)



func unequip_equipment() -> void :
    var equipment: Array[Node] = %EquipmentHolder.get_children()
    for child in equipment:
        child.on_unequip()
        %EquipmentHolder.remove_child(child)
        child.queue_free()



func is_interacting() -> bool:
    return is_instance_valid(held_item) and held_item.holding_interact


func get_look_direction() -> Vector3:
    return - %RotationPivot.get_global_transform().basis.z


func looked_at_by_player() -> void :
    pass


func allow_swarm() -> void :
    if can_swarm:
        swarming = true


func is_future_position_loaded(delta: float) -> bool:
    var future_position: Vector3 = global_position + velocity * delta
    if Ref.world.is_position_loaded(future_position):
        return true
    return _can_use_session_load_proxy() and Ref.coop_manager.is_position_near_same_instance_player(future_position, process_distance)


func distance_process_check() -> void :
    var distance: float = Ref.player.global_position.distance_to(global_position)
    var near_session_player: bool = false
    if _can_use_session_load_proxy():
        var session_distance: float = Ref.coop_manager.get_nearest_session_player_distance(global_position, distance)
        near_session_player = session_distance < distance
        distance = session_distance
    if distance >= process_distance:
        set_physics_process(false)
        set_process(false)

    elif near_session_player or not disabled_by_visibility or %VisibleOnScreenEnabler3D.is_on_screen():
        set_physics_process(true)
        set_process(true)
