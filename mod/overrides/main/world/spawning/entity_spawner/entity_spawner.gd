class_name EntitySpawner extends Node3D


@export var rare_entities: Array[PackedScene]
@export var rare_entity_proportions: Array[float]
@export var spawn_radius: float = 80.0
@export var max_spawns: int = 4
@export var min_time: float = 2.0
@export var max_time: float = 32.0
@export var min_time_rare: float = 1080
@export var max_time_rare: float = 3200
@export var near_distance: float = 6.0
@export var soft_limit_growth: float = 0.01
@export var fail_time: float = 0.6
@export var discovery_base_rate: float = 0.01
@export var rare_spawn_risk_increase: float = 0.1
@export var rare_spawn_base_chance: float = 0.1
const DISCOVERY_SPAWN_COOLDOWN_MSEC: int = 200

@onready var floor_raycast: RayCast3D = %FloorRayCast
@onready var guard_checker: ShapeCast3D = %GuardChecker
@onready var visible_checker: VisibleOnScreenNotifier3D = %VisibleChecker

var risk_factor: int = 0
var entities: Array[Entity] = []
var can_spawn: bool = false

var last_spawn_position: Vector3
var last_discovery_spawn_attempt_msec: int = 0


func _can_use_multi_region_logic() -> bool:
    return multiplayer.is_server() \
        and Ref.coop_manager != null \
        and Ref.coop_manager.has_connected_remote_peers() \
        and Ref.world != null \
        and Ref.world.has_method("uses_coop_multi_region_loading") \
        and bool(Ref.world.call("uses_coop_multi_region_loading"))


func _ready() -> void :
    %SpawnTimer.timeout.connect(_on_timeout.bind(false))
    %RareSpawnTimer.timeout.connect(_on_timeout.bind(true))

    get_tree().get_root().child_entered_tree.connect(_on_child_entered_tree)

    Ref.sun.days_elapsed_changed.connect(_on_days_elapsed_changed)
    Ref.world.chunk_loaded.connect(_on_chunk_loaded)


func _on_chunk_loaded(chunk_position: Vector3i) -> void :
    if not can_spawn:
        return

    if _can_use_multi_region_logic() and _get_same_instance_player_count() > 1:
        var now_msec: int = Time.get_ticks_msec()
        if DISCOVERY_SPAWN_COOLDOWN_MSEC > 0 and now_msec - last_discovery_spawn_attempt_msec < DISCOVERY_SPAWN_COOLDOWN_MSEC:
            return
        last_discovery_spawn_attempt_msec = now_msec

    var chunk_center: Vector3 = Vector3(chunk_position) + Vector3(8, 8, 8)
    if not _is_spawn_region_relevant_to_players(chunk_center):
        return

    var spawn_position: Vector3 = Vector3(chunk_position) + Vector3(randf_range(0, 16), randf_range(0, 16), randf_range(0, 16))
    if not _is_spawn_position_loaded(spawn_position):
        return

    var structure: Structure = Ref.world.get_nearest_structure(spawn_position)
    var biome: Biome = Ref.world.generator.get_biome_at_real(spawn_position)

    if Ref.world.is_within_structure(spawn_position):
        if randf() >= discovery_base_rate * structure.sp_spawn_rate:
            return
    else:
        if randf() >= (discovery_base_rate * (biome.sp_day_spawn_rate if Ref.sun.is_day() else biome.sp_night_spawn_rate)):
            return
    await attempt_spawn(spawn_position, false, false)


func _on_days_elapsed_changed(_day_count: int) -> void :
    if not Ref.world.current_dimension == LucidBlocksWorld.Dimension.NARAKA:
        return

    if randf() < rare_spawn_base_chance + risk_factor * rare_spawn_risk_increase and %RareSpawnTimer.is_stopped():
        %RareSpawnTimer.start(randf_range(min_time_rare, max_time_rare))

    risk_factor += 1


func _on_child_entered_tree(node: Node) -> void :
    if node is Entity and not node is Player:
        if _can_use_multi_region_logic() and not bool(node.get_meta("coop_runtime_spawned", false)):
            return
        entities.append(node as Entity)


func flush_deleted_entities() -> void :
    var new_entities: Array[Entity] = []
    var seen_ids: Dictionary = {}
    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var instance_id: int = entity.get_instance_id()
        if seen_ids.has(instance_id):
            continue
        seen_ids[instance_id] = true
        new_entities.append(entity)
    entities = new_entities


func _get_same_instance_player_count() -> int:
    if not _can_use_multi_region_logic():
        return 1
    return maxi(1, int(Ref.coop_manager.get_same_instance_session_player_count()))


func _get_spawn_group_anchors() -> Array:
    if not _can_use_multi_region_logic() or _get_same_instance_player_count() <= 1:
        return [Ref.player.global_position]

    var raw_positions: Array = Ref.coop_manager.get_same_instance_session_positions()
    var grouped_positions: Array = []
    var merge_distance: float = maxf(spawn_radius, near_distance) * 1.5
    var merge_distance_squared: float = merge_distance * merge_distance

    for raw_position in raw_positions:
        if not (raw_position is Vector3):
            continue
        var position: Vector3 = raw_position
        var merged: bool = false
        for i in range(grouped_positions.size()):
            var existing: Vector3 = grouped_positions[i]
            if existing.distance_squared_to(position) <= merge_distance_squared:
                grouped_positions[i] = existing.lerp(position, 0.5)
                merged = true
                break
        if not merged:
            grouped_positions.append(position)

    if grouped_positions.is_empty():
        grouped_positions.append(Ref.player.global_position)
    return grouped_positions


func _get_spawn_group_count() -> int:
    return maxi(1, _get_spawn_group_anchors().size())


func _get_spawn_cap() -> int:
    var group_count: int = _get_spawn_group_count()
    return max_spawns * group_count


func _get_nearby_spawn_count(spawn_position: Vector3, radius: float) -> int:
    var radius_squared: float = radius * radius
    var nearby_count: int = 0
    for entity in entities:
        if not is_instance_valid(entity) or entity.dead:
            continue
        if entity.global_position.distance_squared_to(spawn_position) <= radius_squared:
            nearby_count += 1
    return nearby_count


func _get_spawn_budget_count(spawn_position: Vector3) -> int:
    if not _can_use_multi_region_logic() or _get_spawn_group_count() <= 1:
        return len(entities)
    return _get_nearby_spawn_count(spawn_position, _get_spawn_interest_radius())


func _get_spawn_interest_radius() -> float:
    if not _can_use_multi_region_logic():
        return spawn_radius + 24.0
    return maxf(spawn_radius + 24.0, Ref.coop_manager.get_same_instance_activity_radius(spawn_radius) + 16.0)


func _is_spawn_position_loaded(pos: Vector3) -> bool:
    if Ref.world.is_position_loaded(pos):
        return true
    if _can_use_multi_region_logic() and _get_same_instance_player_count() > 1:
        return Ref.coop_manager.is_position_near_same_instance_player(pos, spawn_radius + 16.0)
    return false


func _is_spawn_region_relevant_to_players(spawn_position: Vector3) -> bool:
    if not _can_use_multi_region_logic():
        return true
    return Ref.coop_manager.is_position_near_same_instance_player(spawn_position, _get_spawn_interest_radius())


func _is_too_close_to_active_player(spawn_position: Vector3) -> bool:
    if not _can_use_multi_region_logic():
        return spawn_position.distance_to(Ref.player.global_position) < near_distance
    return Ref.coop_manager.is_position_near_same_instance_player(spawn_position, near_distance)


func _get_spawn_anchor() -> Vector3:
    if not _can_use_multi_region_logic():
        return Ref.player.global_position
    return Ref.coop_manager.get_next_same_instance_spawn_anchor(Ref.player.global_position)


func attempt_spawn(spawn_position: Vector3, rare: bool = false, care_for_visibility: bool = true) -> bool:
    if not (Ref.world.current_dimension == LucidBlocksWorld.Dimension.NARAKA or (Ref.world.current_dimension == LucidBlocksWorld.Dimension.FIRMAMENT and not rare)):
        return false
    flush_deleted_entities()

    var player_count: int = _get_spawn_group_count()
    var spawn_budget_count: int = _get_spawn_budget_count(spawn_position)
    if randf() < clamp((float(spawn_budget_count) / float(player_count)) * soft_limit_growth, 0.0, 0.9):
        return false
    if len(entities) >= _get_spawn_cap():
        return false

    if _can_use_multi_region_logic() and _get_same_instance_player_count() > 1:
        var local_spawn_cap: int = max_spawns
        if spawn_budget_count >= local_spawn_cap:
            return false

    if not _is_spawn_position_loaded(spawn_position) or Ref.world.get_block_type_at(spawn_position).id != 0:
        return false

    var structure: Structure = Ref.world.get_nearest_structure(spawn_position)
    var biome: Biome = Ref.world.generator.get_biome_at_real(spawn_position)

    var spawn_proportions: PackedFloat32Array
    var spawns: Array[PackedScene]
    if rare:
        spawn_proportions = rare_entity_proportions
        spawns = rare_entities
    elif Ref.world.is_within_structure(spawn_position):
        spawn_proportions = structure.sp_spawn_proportions
        spawns = structure.sp_spawns
    else:
        spawn_proportions = (biome.sp_day_spawn_proportions if Ref.sun.is_day() else biome.sp_night_spawn_proportions)
        spawns = biome.sp_day_spawns if Ref.sun.is_day() else biome.sp_night_spawns

    if len(spawns) == 0:
        return false

    var entity: Entity = get_random_spawn(spawns, spawn_proportions).instantiate()

    if Ref.world.is_under_water(spawn_position) != entity.spawn_in_water:
        entity.queue_free()
        return false

    if not entity.spawn_in_water:
        floor_raycast.global_position = spawn_position
        floor_raycast.force_raycast_update()

        if not floor_raycast.is_colliding():
            entity.queue_free()
            return false

        spawn_position = floor_raycast.get_collision_point()
        if not _is_spawn_position_loaded(spawn_position + Vector3(0, 0.1, 0)) or Ref.world.is_under_water(spawn_position + Vector3(0, 0.1, 0)):
            entity.queue_free()
            return false

    if _is_too_close_to_active_player(spawn_position):
        entity.queue_free()
        return false

    guard_checker.global_position = spawn_position
    guard_checker.force_shapecast_update()
    if guard_checker.is_colliding():
        entity.queue_free()
        return false

    if care_for_visibility:
        visible_checker.global_position = spawn_position
        await RenderingServer.frame_post_draw

        if not can_spawn:
            if is_instance_valid(entity):
                entity.queue_free()
            return false

        if visible_checker.is_on_screen():
            entity.queue_free()
            return false

    entity.transform.origin = spawn_position
    entity.allow_swarm()
    entity.set_meta("coop_runtime_spawned", true)
    if not multiplayer.is_server():
        entity.set_meta("coop_guest_local_authority", true)
    get_tree().get_root().add_child(entity)
    if Ref.coop_manager != null and Ref.coop_manager.has_method("ensure_runtime_entity_uuid"):
        Ref.coop_manager.call("ensure_runtime_entity_uuid", entity)

    entities.append(entity)

    last_spawn_position = spawn_position

    return true


func _on_timeout(rare: bool = false) -> void :
    var timer: Timer = %RareSpawnTimer if rare else %SpawnTimer
    var player_count: int = _get_spawn_group_count()
    var spawned: bool = false

    if _can_use_multi_region_logic() and _get_same_instance_player_count() > 1 and not rare:
        var positions: Array = _get_spawn_group_anchors()
        for pos in positions:
            var spawn_pos: Vector3 = _get_spawn_position_near(pos)
            if await attempt_spawn(spawn_pos, false):
                spawned = true
    else:
        spawned = await attempt_spawn(get_player_based_spawn_position(), rare)

    if not spawned:
        timer.start(maxf(0.15, fail_time / float(player_count)))
    else:
        if not rare:
            if _is_spawn_position_loaded(last_spawn_position) and Ref.world.is_within_structure(last_spawn_position):
                timer.start(randf_range(min_time, max_time) / (Ref.world.get_nearest_structure(last_spawn_position).sp_spawn_rate * float(player_count)))
            else:
                var biome: Biome = Ref.world.generator.get_biome_at_real(last_spawn_position)
                timer.start(randf_range(min_time, max_time) / ((biome.sp_day_spawn_rate if Ref.sun.is_day() else biome.sp_night_spawn_rate) * float(player_count)))
        else:
            risk_factor = 0
            timer.stop()


func _get_spawn_position_near(anchor: Vector3) -> Vector3:
    var spawn_position: Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
    spawn_position = spawn_position.normalized() * randf_range(0.1, 1) * spawn_radius
    spawn_position += anchor
    return spawn_position


func get_player_based_spawn_position() -> Vector3:
    var anchor: Vector3 = _get_spawn_anchor()
    var spawn_position: Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
    spawn_position = spawn_position.normalized() * randf_range(0.1, 1) * spawn_radius
    spawn_position += anchor

    if spawn_position.distance_to(anchor) <= near_distance:
        var away_direction: Vector3 = spawn_position - anchor
        if away_direction.is_zero_approx():
            away_direction = Vector3.FORWARD
        spawn_position += away_direction.normalized() * near_distance

    return spawn_position


func get_random_spawn(spawns: Array[PackedScene], chances: Array[float]) -> PackedScene:
    var total_proportion: float = 0
    var running_sum: Array[float] = []
    for proportion in chances:
        total_proportion += proportion
        running_sum.append(total_proportion)
    var x: float = randf_range(0, total_proportion)
    var to_spawn: PackedScene = spawns[0]
    for i in range(len(chances)):
        if x <= running_sum[i]:
            to_spawn = spawns[i]
            break
    return to_spawn


func start_spawning() -> void :
    stop_spawning()
    if Ref.world.current_dimension == LucidBlocksWorld.Dimension.NARAKA or Ref.world.current_dimension == LucidBlocksWorld.Dimension.FIRMAMENT:
        %SpawnTimer.start(randf_range(min_time, max_time))
        can_spawn = true


func stop_spawning() -> void :
    %SpawnTimer.stop()
    %RareSpawnTimer.stop()
    can_spawn = false


func save_file(file: SaveFile) -> void :
    file.set_data("entity_spawner/risk_factor", risk_factor)


func load_file(file: SaveFile) -> void :
    risk_factor = file.get_data("entity_spawner/risk_factor", 0)
