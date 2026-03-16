class_name Hamsa extends Entity

@export var teleport_radius: float = 50.0
@export var near_radius: float = 4.0
@export var chase_chance: float = 0.25
@export var idle_time_min: float = 3.0
@export var idle_time_max: float = 8.0

var desired_angle: float
var teleport_amount: float = 0.0:
    set(val):
        teleport_amount = val
        %Fractal.set_instance_shader_parameter("fuzzy_alpha", 1.0 - teleport_amount)

enum {CHASE, IDLE}

var state: int = IDLE

func _ready() -> void :
    super._ready()

    modulate_changed.connect(_on_modulate_changed)
    alpha_changed.connect(_on_alpha_changed)

    desired_angle = randf_range(0, 2 * PI)
    %RotationPivot.rotation.y = desired_angle

    %IdleTimer.timeout.connect(_on_idle_timeout)
    %IdleTimer.start(randf_range(idle_time_min, idle_time_max))

    tree_exiting.connect(_on_tree_exiting)






func _on_tree_exiting() -> void :
    if state == CHASE and Ref.sun.target_time_scale < 1.0:
        Ref.sun.set_time_scale(1.0)


func _get_target_position() -> Vector3:
    return get_session_target_entity_position(global_position, Ref.player)


func _get_target_head_position() -> Vector3:
    return get_session_target_entity_head_position(global_position + Vector3(0, 1.45, 0), Ref.player)


func _on_idle_timeout() -> void :
    if not state == IDLE or dead or disabled or not is_inside_tree():
        return

    var will_teleport: bool = randf() < chase_chance
    if not Ref.world.current_dimension == LucidBlocksWorld.Dimension.NARAKA:
        will_teleport = false

    for i in range(8):
        if await teleport(will_teleport):
            break
    if will_teleport:
        %IdleTimer.stop()
        if Ref.sun.target_time_scale >= 1.0:
            var new_player: AudioStreamPlayer3D = %BellPlayer.duplicate()
            new_player.finished.connect(new_player.queue_free)
            get_tree().get_root().add_child(new_player)
            new_player.global_position = hand.global_position
            new_player.play()
            await Ref.sun.set_time_scale(0.5)
        state = CHASE
    %IdleTimer.start(randf_range(idle_time_min, idle_time_max))

func _physics_process(delta: float) -> void :
    if dead or disabled or not is_session_position_loaded(global_position):
        return
    distance_process_check()
    if state == CHASE:


        if Ref.sun.target_time_scale >= 1.0:
            state = IDLE
            %IdleTimer.start(randf_range(idle_time_min, idle_time_max))
            return
        var center: Vector3 = _get_target_head_position()

        if is_session_position_loaded(global_position + global_position.direction_to(center) * delta * speed):
            global_position += global_position.direction_to(center) * delta * speed


        SpatialMath.look_at( %RotationPivot, _get_target_head_position())

        if global_position.distance_to(center) < 1.0:
            travel()


func _on_modulate_changed(new_modulate: Color) -> void :
    %Fractal.set("instance_shader_parameters/albedo", new_modulate)


func _on_alpha_changed(new_alpha: float) -> void :
    %Fractal.set("instance_shader_parameters/fade", new_alpha)


func teleport(final: bool) -> bool:
    var spawn_position: Vector3 = Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1))
    spawn_position = spawn_position.normalized() * randf_range(0.1, 1) * teleport_radius
    spawn_position += _get_target_position()

    if is_session_position_loaded(spawn_position) and Ref.world.is_block_solid_at(spawn_position):
        return false

    %SpawnRay.global_position = spawn_position
    %SpawnRay.force_raycast_update()
    if %SpawnRay.is_colliding():
        spawn_position = %SpawnRay.get_collision_point()

    if spawn_position.distance_to(_get_target_position()) <= near_radius:
        return false

    var new_player: AudioStreamPlayer3D = %TeleportPlayer.duplicate()
    new_player.finished.connect(new_player.queue_free)
    get_tree().get_root().add_child(new_player)
    new_player.global_position = hand.global_position
    new_player.play()

    var tween: Tween = get_tree().create_tween()
    tween.tween_property(self, "teleport_amount", 1.0, 1.0)
    await tween.finished

    global_position = spawn_position

    if final:
        SpatialMath.look_at( %RotationPivot, _get_target_head_position())

    new_player = %TeleportPlayer.duplicate()
    new_player.finished.connect(new_player.queue_free)
    new_player.pitch_scale = 0.8
    get_tree().get_root().add_child(new_player)
    new_player.global_position = hand.global_position
    new_player.play()

    tween = get_tree().create_tween()
    tween.tween_property(self, "teleport_amount", 0.0, 1.0)
    await tween.finished

    return true

func travel() -> void :
    queue_free()
    Ref.sun.set_time_scale(1.0)
    Ref.main.teleport_to_dimension(LucidBlocksWorld.Dimension.FIRMAMENT)


func preserve_save(file: SaveFile, uuid: String) -> void :
    super.preserve_save(file, uuid)
    file.set_data("node/%s/state" % uuid, state)


func preserve_load(file: SaveFile, uuid: String) -> void :
    super.preserve_load(file, uuid)
    state = file.get_data("node/%s/state" % uuid, IDLE)
