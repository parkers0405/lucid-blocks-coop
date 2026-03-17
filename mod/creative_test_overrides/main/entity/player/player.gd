class_name Player extends Entity


@export_group("Movement")
@export var sprint_speed_multiplier: float = 1.3
@export var jump_speed_multiplier: float = 1.1
@export var crouch_speed_multiplier: float = 0.3
@export var fly_speed_multiplier: float = 8
@export var fly_impulse: float = 9.0
@export var minimum_sprint_speed: float = 1.0

@export_group("Animation")
@export var crouch_time: float = 0.125
@export var spring_fov_time: float = 0.25

@export_group("Other")
@export var spawn_invincibility_time: float = 5.0
@export var fov_spring_scale: float = 1.15
@export var sprint_difference_threshold: float = 0.1
@export var starter_kit: Array[Item]


var sprint_toggle: bool = false
var crouch_toggle: bool = false
var left_handed: bool = false
var invert_mouse_y: bool = false
var might_double_jump: bool = false
var mouse_sensitivity: float = 0.01
var fov: float = 86
var controller_camera_sensitivity: float = 1.0


var consumed_actions: Array[String] = []
var flying: bool = false
var is_sprinting_requested: bool = false
var is_croucing_requested: bool = false
var is_sprinting: bool = false
var is_crouching: bool = false:
    set(val):
        is_crouching = val
        crouching_changed.emit(val)
var can_switch_hotbar: bool = true
var attack_used: bool = false
var is_breaking_block: bool = false
var current_structure: Structure = null
var can_interact_with_block: bool = false:
    set(val):
        can_interact_with_block = val
        can_interact_with_block_changed.emit(val)
var can_interact_using_item: bool = false:
    set(val):
        can_interact_using_item = val
        can_interact_using_item_changed.emit(val)


var camera_height: float = 0.0
var camera_fov: float = 0.0


var teleport_location: Vector3
var teleport: bool = false


var push_bodies: Dictionary[Entity, bool]

signal structure_changed(new_structure: Structure)
signal can_interact_with_block_changed(value: bool)
signal can_interact_using_item_changed(value: bool)
signal crouching_changed(value: bool)


func _ready() -> void :
    super._ready()



    remove_from_group("preserve_but_delete_on_unload")
    remove_from_group("preserve")

    Ref.save_file_manager.settings_updated.connect(_on_settings_updated)
    _on_settings_updated()

    held_item_index_changed.connect(_on_held_item_index_changed)

    %PushArea3D.body_entered.connect(_on_body_entered)
    %PushArea3D.body_exited.connect(_on_body_exited)

    %Burn.burning_started.connect(_on_burning_started)
    %Burn.burning_stopped.connect(_on_burning_stopped)

    %FlyTimer.timeout.connect(_on_fly_timeout)
    %SpawnInvincibilityTimer.timeout.connect(_on_spawn_invincibility_timeout)

    damage_taken.connect(_on_damage_taken)

    Ref.main.new_game_loaded.connect(_on_new_game)
    print("Player ready.")


func _on_settings_updated() -> void :
    fov = int(Ref.save_file_manager.settings_file.get_data("fov", 86))
    sprint_toggle = Ref.save_file_manager.settings_file.get_data("sprint_toggle", false)
    crouch_toggle = Ref.save_file_manager.settings_file.get_data("crouch_toggle", false)
    left_handed = Ref.save_file_manager.settings_file.get_data("left_hand", false)
    invert_mouse_y = Ref.save_file_manager.settings_file.get_data("invert_look_y", false)
    mouse_sensitivity = (0.001 + Ref.save_file_manager.settings_file.get_data("camera_sensitivity", 14) / 1000.0)
    controller_camera_sensitivity = 0.25 + 1.75 * Ref.save_file_manager.settings_file.get_data("controller_camera_sensitivity", 14) / 14.0

    %Camera3D.shake_enabled = Ref.save_file_manager.settings_file.get_data("screen_shake", true)
    %PlayerHand.visible = Ref.save_file_manager.settings_file.get_data("show_hand", true)

    hand.position.x = abs(hand.position.x) * (-1.0 if left_handed else 1.0)


func consume_actions() -> void :
    consumed_actions.clear()
    for action in ["jump", "crouch", "attack", "interact"]:
        if Input.is_action_pressed(action):
            consumed_actions.append(action)


func is_action_pressed_safe(action: String) -> bool:
    if action in consumed_actions:
        if Input.is_action_just_released(action):
            consumed_actions.erase(action)
        return false
    return Input.is_action_pressed(action)


func _on_fly_timeout() -> void :
    might_double_jump = false


func _on_spawn_invincibility_timeout() -> void :
    invincible_temporary = false


func make_invincible_temporary() -> void :
    invincible_temporary = true
    %SpawnInvincibilityTimer.start(spawn_invincibility_time)


func remove_temporary_invincible() -> void :
    %SpawnInvincibilityTimer.stop()
    invincible_temporary = false


func _on_damage_taken(_damage: int) -> void :
    %Camera3D.camera_shake(0.2, 0.04)


func _on_burning_started() -> void :
    %EntityFireVisual.enter()


func _on_burning_stopped() -> void :
    %EntityFireVisual.exit()


func _on_body_entered(body: PhysicsBody3D) -> void :
    push_bodies[body as Entity] = true


func _on_body_exited(body: PhysicsBody3D) -> void :
    push_bodies.erase(body)


func _on_held_item_index_changed() -> void :
    %PlayerHand.switch_item(held_item, %Hotbar.items[held_item_index])


func _on_instant_interact_impulse() -> void :
    %PlayerHand.interact()


func _process(delta: float) -> void :
    if disabled:
        return


    if Ref.main.debug and Input.is_action_just_pressed("debug_jump"):
        global_position.y += 256 if not is_crouching else -256

    if not Ref.world.is_position_loaded(global_position):
        return


    var local_movement_enabled: bool = movement_enabled and MouseHandler.fully_captured
    var joy_input: Vector2 = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
    if local_movement_enabled and is_processing_input() and joy_input != Vector2.ZERO:
        %RotationPivot.rotate_y( - joy_input.x * controller_camera_sensitivity * delta)
        var y_direction: float = -1.0 if not invert_mouse_y else 1.0
        %Camera3D.rotate_x(y_direction * joy_input.y * controller_camera_sensitivity * delta)
        %Camera3D.rotation.x = clampf( %Camera3D.rotation.x, - deg_to_rad(90), deg_to_rad(90))

    check_water()
    camera_process(delta)
    update_walk_animation()


    if not local_movement_enabled:
        if %BreakBlocks.breaking:
            %BreakBlocks.break_block_stop()
        if is_interacting():
            held_item.interact_end()
            if %PlayerHand.current_hand.state == PlayerHandVariant.State.INTERACT_SUSTAIN:
                %PlayerHand.interact_sustain_end()
    else:

        var data: Dictionary = get_interact_data()

        interaction_process(data)
        attack_process(data)

    update_pointer_visual.call_deferred()
    hand_process()
    %PlayerHand.position = ( %Camera3D.unproject_position( %Hand.global_position) - %PlayerHand.scale * %PlayerHand.offset)


func _physics_process(delta: float) -> void :
    var local_movement_enabled: bool = movement_enabled and MouseHandler.fully_captured

    gravity_direction_multiplier = -1 if Ref.main.upside_down else 1

    if disabled or not Ref.world.is_position_loaded(global_position):
        return

    update_structure()
    super._physics_process(delta)
    if is_future_position_loaded(delta):
        move_and_slide()

    if not dead and not invincible and (Ref.world.current_dimension == LucidBlocksWorld.Dimension.CHALLENGE or Ref.world.current_dimension == LucidBlocksWorld.Dimension.FIRMAMENT) and global_position.y < -128:
        health -= 1
    var input: Vector2 = Input.get_vector("left", "right", "up", "down") if local_movement_enabled else Vector2()
    var movement_dir: Vector3 = %RotationPivot.global_transform.basis * Vector3(input.x, 0, input.y)

    if not sprint_toggle:
        is_sprinting_requested = is_action_pressed_safe("sprint")
    if not crouch_toggle:
        is_croucing_requested = is_action_pressed_safe("crouch")
    if local_movement_enabled and might_double_jump and is_action_pressed_safe("jump") and Input.is_action_just_pressed("jump"):
        might_double_jump = false
        %FlyTimer.stop()
        flying = not flying
    flying = flying and (Ref.main.debug or invincible)

    is_sprinting = flying and not is_interacting() and local_movement_enabled and is_sprinting_requested

    is_crouching = is_croucing_requested and not is_sprinting and local_movement_enabled

    var target_speed: float = speed * speed_modifier
    var accel: float = ground_accel * accel_modifier

    if is_crouching:
        target_speed = speed * crouch_speed_multiplier * speed_modifier

    if not is_on_floor() and not is_crouching:
        accel = air_accel * accel_modifier * air_accel_modifier
        target_speed *= jump_speed_multiplier

    if is_on_ceiling() and gravity_direction_multiplier * movement_velocity.y > 0:
        movement_velocity.y = 0

    if flying:
        target_speed = speed * fly_speed_multiplier * speed_modifier
        if is_sprinting:
            target_speed *= sprint_speed_multiplier
        static_gravity_modifier = 0.0
    else:
        static_gravity_modifier = 1.0

    default_entity_movement(
        delta, movement_dir, accel, target_speed * speed_modifier, local_movement_enabled and is_on_floor() and is_action_pressed_safe("jump"), local_movement_enabled and is_action_pressed_safe("jump"), local_movement_enabled and is_action_pressed_safe("crouch")
    )

    if is_action_pressed_safe("jump") and Input.is_action_just_pressed("jump"):
        %FlyTimer.start()
        might_double_jump = true

    if flying and local_movement_enabled:
        fly_process()

    if is_crouching and is_on_floor():
        crouch_snap(delta)

    push_process(delta)



func _input(event: InputEvent) -> void :
    if disabled:
        return

    if can_switch_hotbar and MouseHandler.fully_captured:
        var new_index: int = held_item_index
        for i in range(6):
            if event.is_action_pressed("hotbar_%d" % (i + 1), false):
                new_index = i
        if event.is_action_pressed("hotbar_next", false):
            new_index += 1
        if event.is_action_pressed("hotbar_back", false):
            new_index -= 1
        if new_index < 0:
            new_index += 6
        new_index = new_index % 6

        if held_item_index != new_index:
            hold_item(new_index)

    var local_movement_enabled: bool = movement_enabled and MouseHandler.fully_captured
    if local_movement_enabled and is_instance_valid(held_item) and event.is_action_pressed("drop_item", false):
        %DropItems.drop_and_remove_from_inventory( %Hotbar, held_item_index)

    if event is InputEventMouseMotion and local_movement_enabled:
        %RotationPivot.rotate_y( - event.relative.x * mouse_sensitivity)

        var y_direction: float = -1.0 if not invert_mouse_y else 1.0
        %Camera3D.rotate_x(y_direction * event.relative.y * mouse_sensitivity)
        %Camera3D.rotation.x = clampf( %Camera3D.rotation.x, - deg_to_rad(90), deg_to_rad(90))

    if sprint_toggle and event.is_action_pressed("sprint", false):
        is_sprinting_requested = not is_sprinting_requested

    if crouch_toggle and event.is_action_pressed("crouch", false):
        is_croucing_requested = not is_croucing_requested




func initialize() -> void :
    %BreakBlocks.break_block_stop()
    %Drown.reset()
    %Burn.reset()

    force_check_update = true
    invincible = Ref.main.creative
    is_sprinting_requested = false
    is_croucing_requested = false
    is_sprinting = false
    is_crouching = false
    under_water = false
    head_under_water = false
    feet_under_water = false
    attack_used = false
    is_breaking_block = false
    dead = false
    camera_height = 0.0
    camera_fov = 0.0
    static_speed_modifier = 1.0
    static_accel_modifier = 1.0
    static_gravity_modifier = 1.0
    glider_gravity_modifier = 1.0
    glider_speed_modifier = 1.0
    first_frame = true
    current_biome = null
    push_bodies.clear()
    hand_process()


func _on_new_game() -> void :
    %PlayerHand.visible = Ref.save_file_manager.settings_file.get_data("show_hand", true)
    %HarmCover.visible = true
    health = 10
    max_health = 10
    hate = 1
    lust = 3
    faith = 2

    if Ref.main.debug and not Ref.main.creative and Ref.save_file_manager.loaded_file_register.get_data("starter_kit", false):
        for i in range(len(starter_kit)):
            var new_item: ItemState = ItemState.new()
            new_item.initialize(starter_kit[i])
            new_item.count = ItemMap.map(new_item.id).stack_size
            held_item_inventory.set_item(i, new_item)


func save_file(file: SaveFile) -> void :
    super.preserve_save(file, "player")

    file.set_data("node/player/global_position", global_position, false)
    file.set_data("node/player/camera_angle", %Camera3D.rotation.x, false)
    file.set_data("node/player/flying", flying, true)


func load_file(file: SaveFile) -> void :
    super.preserve_load(file, "player")

    %Camera3D.rotation.x = file.get_data("node/player/camera_angle", %Camera3D.rotation.x, false)
    global_position = file.get_data("node/player/global_position", Vector3(0, 0, 0), false)
    flying = file.get_data("node/player/flying", false, true)

func die() -> void :
    if disabled or dead:
        return

    if Ref.main.in_challenge or Ref.main.in_ending:
        Ref.game_menu.deactivate()
        disabled = true
        get_tree().paused = true
        Ref.audio_manager.fade_out_sfx()

        await Ref.trans.open_scary()

        if Ref.main.in_challenge:
            print("End challenge...")
            Ref.main.end_challenge(false)
        if Ref.main.in_ending:
            print("End ending...")
            Ref.main.end_ending(false)
        Ref.plot_manager.remove_cutscene()
        revive()

        await Ref.main.teleport_to_dimension(LucidBlocksWorld.Dimension.NARAKA, true)
    else:
        druj += 1
        dead = true


func revive() -> void :
    health = max_health
    movement_velocity = Vector3()
    rope_velocity = Vector3()
    gravity_velocity = Vector3()
    knockback_velocity = Vector3()
    velocity = Vector3()
    last_velocity_y = 0
    has_endure = true
    %Burn.burning = false
    %Drown.air = %Drown.max_air


func get_look_direction() -> Vector3:
    if %AimRayCast3D.is_colliding():
        return ( %AimRayCast3D.get_collision_point() - hand.global_position).normalized()
    return ( %AimRayCast3D.to_global( %AimRayCast3D.target_position) - hand.global_position).normalized()



func hand_process() -> void :
    var current_hand: PlayerHandVariant = %PlayerHand.current_hand
    if %BreakBlocks.breaking and current_hand.state != PlayerHandVariant.State.HIT_SUSTAIN:
        current_hand.hit_sustain_start()
    if not %BreakBlocks.breaking and current_hand.state == PlayerHandVariant.State.HIT_SUSTAIN:
        current_hand.hit_sustain_end()



func camera_process(delta: float) -> void :
    if is_sprinting:
        camera_fov += delta / spring_fov_time
    else:
        camera_fov -= delta / spring_fov_time
    camera_fov = clamp(camera_fov, 0.0, 1.0)

    %Camera3D.fov = lerp(fov, fov * fov_spring_scale, ease(camera_fov, -2.0))

    if is_crouching:
        camera_height += delta / crouch_time
    else:
        camera_height -= delta / crouch_time

    camera_height = clamp(camera_height, 0.0, 1.0)
    %CameraPivot.position = lerp( %HeadPointNormal.position, %HeadPointCrouch.position, ease(camera_height, -2.0))

    %Arm.position = %CameraPivot.position
    %Arm.rotation.x = %Camera3D.rotation.x
    %Arm.rotation.y = %RotationPivot.rotation.y



func attack_process(data: Dictionary) -> void :
    var attack_pressed: bool = is_action_pressed_safe("attack")
    if not is_interacting():
        if attack_pressed and Input.is_action_just_pressed("attack"):
            if "ball_target" in data and data.ball_target.can_parry:
                attack_used = true
                data.ball_target.apply_impulse(velocity * 0.25 + get_look_direction() * 28.0)
                data.ball_target.attacked()
                %WhiffPlayer.play()
                %PlayerHand.current_hand.hit()
            if "target" in data:
                if Ref.coop_manager != null and not multiplayer.is_server():
                    var target = data.target
                    var target_name: String = target.name if target is Node else str(target)
                    var target_uuid: String = str(target.get_meta("coop_uuid", "")) if is_instance_valid(target) else ""
                    print("[lucid-blocks-coop][attack-debug] guest target=", target_name, " class=", target.get_class(), " uuid=", target_uuid)
                attack_used = true
                %WhiffPlayer.play()
                %Attack.attack(data.target, data.get("attack_position", %InteractRayCast3D.get_collision_point()))
                %PlayerHand.current_hand.hit()
                %Camera3D.camera_shake()
            elif "target_position" in data:
                if Ref.coop_manager != null and not multiplayer.is_server():
                    print("[lucid-blocks-coop][attack-debug] guest block target=", data.target_position, " collider=", data.get("debug_collider", "<none>"), " resolved=", data.get("debug_resolved", "<none>"))
                pass
            else:
                if Ref.coop_manager != null and not multiplayer.is_server():
                    print("[lucid-blocks-coop][attack-debug] guest whiff collider=", data.get("debug_collider", "<none>"), " resolved=", data.get("debug_resolved", "<none>"))
                %WhiffPlayer.play()
                %PlayerHand.hit()

        var debug_always_breaking: bool = false
        if not attack_used and not "target" in data and not %BreakBlocks.breaking:



            var invisible_block_seen: bool = false
            var potential_cells: Array[Vector3] = BlockMath.visit_all(data.interact_begin, data.interact_end)
            for place_position in potential_cells:
                place_position = place_position.floor()
                if not Ref.world.is_position_loaded(place_position):
                    continue
                if not Ref.world.is_block_solid_at(place_position) and is_instance_valid(Ref.world.get_living_block_at(place_position)):
                    if attack_pressed and Input.is_action_just_pressed("attack"):
                        %BreakBlocks.break_block_instant(Vector3i(place_position))
                    invisible_block_seen = true
                    break
            if (debug_always_breaking or attack_pressed) and not invisible_block_seen and "target_position" in data:
                is_breaking_block = true
                %BreakBlocks.break_block_start(data.target_position)
        if %BreakBlocks.breaking and ( not (debug_always_breaking or attack_pressed) or not "target_position" in data or not Vector3i(data.target_position) == %BreakBlocks.active_position):
            is_breaking_block = false
            %BreakBlocks.break_block_stop()
        if Input.is_action_just_released("attack"):
            attack_used = false
        if not attack_pressed:
            is_breaking_block = false



func interaction_process(data: Dictionary) -> void :
    if disabled:
        return
    var interact_pressed: bool = is_action_pressed_safe("interact")

    can_interact_with_block = ("target_position" in data and is_instance_valid(Ref.world.get_living_block_at(data.target_position)) and Ref.world.get_living_block_at(data.target_position).can_currently_interact(self))
    can_interact_using_item = is_instance_valid(held_item) and held_item.can_interact(data)


    if not is_breaking_block and not is_crouching and interact_pressed and Input.is_action_just_pressed("interact") and can_interact_with_block:
        var living_block: LivingBlock = Ref.world.get_living_block_at(data.target_position) as LivingBlock
        living_block.interact(self)

    elif interact_pressed and Input.is_action_just_pressed("interact") and not is_interacting() and is_instance_valid(held_item):
        var interaction_type: int = held_item.interaction_type
        var success: bool = can_interact_using_item and await held_item.interact(true, data)
        if success:
            if is_breaking_block:
                %BreakBlocks.break_block_stop()

            if interaction_type == 0:
                %PlayerHand.interact()
            else:
                %PlayerHand.interact_sustain_start()

    elif not interact_pressed and is_interacting():
        if %PlayerHand.current_hand.state == PlayerHandVariant.State.INTERACT_SUSTAIN:
            %PlayerHand.interact_sustain_end()
        held_item.interact_end()


    if is_interacting() and not held_item.holding_animation and %PlayerHand.current_hand.state == PlayerHandVariant.State.INTERACT_SUSTAIN:
        %PlayerHand.interact_sustain_end()


func fly_process() -> void :
    gravity_velocity.y = 0
    if is_action_pressed_safe("jump"):
        movement_velocity.y = (gravity_direction_multiplier * fly_impulse * (sprint_speed_multiplier if is_sprinting else 1.0))
    elif is_action_pressed_safe("crouch"):
        movement_velocity.y = - gravity_direction_multiplier * fly_impulse
    else:
        movement_velocity.y = 0


func push_process(delta: float) -> void :
    for body in push_bodies:
        if not is_instance_valid(body) or body == self:
            continue
        var distance: float = body.global_position.distance_squared_to(global_position)
        if distance > 0.75:
            continue
        var t: float = pow(1.0 - distance / 0.75, 2)
        body.knockback_velocity += (8 * (velocity * 0.1 + 16.0 * t * (body.global_position - global_position).normalized()) * delta * clamp(weight / body.weight, 0.0, 12.0))


func crouch_snap(delta: float) -> void :
    %FloorShapeCast3D.global_position = global_position + Vector3(movement_velocity.x * delta, 0, 0)
    %FloorShapeCast3D.force_shapecast_update()
    if not %FloorShapeCast3D.is_colliding():
        movement_velocity.x = 0

    %FloorShapeCast3D.global_position = global_position + Vector3(0, 0, movement_velocity.z * delta)
    %FloorShapeCast3D.force_shapecast_update()
    if not %FloorShapeCast3D.is_colliding():
        movement_velocity.z = 0



func update_walk_animation() -> void :
    %AnimationPlayer.speed_scale = (0.5 if is_crouching else 1.25)
    if Vector3(velocity.x, 0, velocity.z).length() > 0.1 and not in_air:
        %AnimationPlayer.current_animation = "walk"
    else:
        %AnimationPlayer.stop()



func update_pointer_visual() -> void :
    var data: Dictionary = get_interact_data(true)
    %BlockOutline.visible = false
    if "target_position" in data:
        %BlockOutline.global_position = data.target_position + Vector3(0.5, 0.5, 0.5)
        %BlockOutline.visible = true



func update_structure() -> void :
    var structure: Structure = Ref.world.get_nearest_structure(global_position)
    if not Ref.world.is_within_structure(global_position):
        structure = null
    if structure != current_structure:
        current_structure = structure
        structure_changed.emit(current_structure)



func _resolve_interact_owner_from_collider(collider: Object):
    if not is_instance_valid(collider):
        return null
    if collider.has_meta("coop_hit_owner"):
        var coop_hit_owner = collider.get_meta("coop_hit_owner")
        if is_instance_valid(coop_hit_owner) and (coop_hit_owner is Ball or coop_hit_owner is Heart or coop_hit_owner is Entity):
            return coop_hit_owner
    if collider is Ball or collider is Heart or collider is Entity:
        return collider

    var current: Node = collider as Node
    while current != null:
        if current.has_meta("coop_hit_owner"):
            var current_coop_hit_owner = current.get_meta("coop_hit_owner")
            if is_instance_valid(current_coop_hit_owner) and (current_coop_hit_owner is Ball or current_coop_hit_owner is Heart or current_coop_hit_owner is Entity):
                return current_coop_hit_owner
        if current is Ball or current is Heart or current is Entity:
            return current
        if current.owner is Ball or current.owner is Heart or current.owner is Entity:
            return current.owner
        current = current.get_parent()
    return null


func get_interact_data(skip_look: bool = false) -> Dictionary:
    var data: Dictionary = {}

    if skip_look:
        if %LookRayCast3D.is_colliding():
            var collider: Object = %LookRayCast3D.get_collider()
            var look_target = _resolve_interact_owner_from_collider(collider)
            if look_target is Entity:
                var look_entity := look_target as Entity
                if is_instance_valid(look_entity) and not look_entity.disabled and not look_entity.dead:
                    look_entity.looked_at_by_player()

    data.interact_begin = %InteractRayCast3D.global_position
    data.interact_end = %InteractRayCast3D.to_global( %InteractRayCast3D.target_position)
    data.interact_normal = %InteractRayCast3D.get_collision_normal()
    data.interact_end_adjacent = ( %InteractRayCast3D.get_collision_point() + %InteractRayCast3D.get_collision_normal() * 0.5)




    var non_block_position: Vector3
    var non_block_collision: bool = false
    for i in range(2):
        %InteractRayCast3D.set_collision_mask_value(1, i == 1)
        %InteractRayCast3D.force_raycast_update()
        if %InteractRayCast3D.is_colliding():
            data.interact_end = %InteractRayCast3D.get_collision_point()

            var collider: Object = %InteractRayCast3D.get_collider()
            var resolved_target = _resolve_interact_owner_from_collider(collider)
            var collider_name: String = collider.name if collider is Node else str(collider)
            var resolved_name: String = resolved_target.name if resolved_target is Node else str(resolved_target)
            data["debug_collider"] = "%s:%s" % [collider.get_class(), collider_name]
            data["debug_resolved"] = "%s:%s" % [resolved_target.get_class(), resolved_name] if is_instance_valid(resolved_target) else "<none>"
            if resolved_target is Ball or resolved_target is Heart:
                data.ball_target = resolved_target
                non_block_position = data.interact_end
                non_block_collision = true
                data.attack_position = data.interact_end
            elif resolved_target is Entity:
                data.target = resolved_target as Entity
                non_block_position = data.interact_end
                non_block_collision = true
                data.attack_position = data.interact_end
            else:

                if (
                    non_block_collision
                    and (non_block_position.distance_to(data.interact_end) < 0.001 or ( %InteractRayCast3D.global_position.distance_squared_to(non_block_position) < %InteractRayCast3D.global_position.distance_squared_to(data.interact_end)))
                ):
                    data.interact_end = non_block_position
                else:
                    data.erase("target")
                    data.erase("ball_target")

                    var target_position: Vector3 = ( %InteractRayCast3D.get_collision_point() - %InteractRayCast3D.get_collision_normal() * 0.5).floor()
                    if Ref.world.is_position_loaded(target_position) and Ref.world.is_block_solid_at(target_position):
                        data.target_position = target_position
                        data.target_position_adjacent = (data.target_position + %InteractRayCast3D.get_collision_normal())

    if not data.has("target") and not data.has("ball_target") and Ref.coop_manager != null and not multiplayer.is_server():
        var fallback_target = Ref.coop_manager.find_client_ray_attack_target(data.interact_begin, data.interact_end)
        if is_instance_valid(fallback_target):
            data.erase("target_position")
            data.erase("target_position_adjacent")
            data.target = fallback_target
            data.attack_position = Ref.coop_manager.get_client_attack_hit_position(fallback_target, data.interact_begin, data.interact_end)
            data["debug_resolved"] = "fallback:%s:%s" % [fallback_target.get_class(), fallback_target.name if fallback_target is Node else str(fallback_target)]

    return data
