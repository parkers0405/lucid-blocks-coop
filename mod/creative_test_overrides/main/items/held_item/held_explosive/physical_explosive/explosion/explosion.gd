class_name Explosion extends Node3D

var entity_owner: Entity

@export var explode_radius: int = 4
@export var attacks_self: bool = true
@export var knockback_strength: float = 8.0
@export var knockback_boost: Vector3 = Vector3(0, 4, 0)
@export var max_damage: int = 10
@export var firey: bool = false
@export var watery: bool = false
@export var hate_scale: float = 0.0
@onready var light: OmniLight3D = %Light


func _ready() -> void:
    Ref.save_file_manager.settings_updated.connect(_on_settings_updated)
    _on_settings_updated()


func _on_settings_updated() -> void:
    var shadow_quality: int = Ref.save_file_manager.settings_file.get_data("shadow_quality", 2)
    if shadow_quality == 0:
        light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
    else:
        light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE


func _capture_world_change_snapshot() -> Dictionary:
    var snapshot: Dictionary = {}
    var scan_radius: int = int(ceil(float(explode_radius))) + 1
    var center: Vector3i = Vector3i(global_position.floor())

    for y in range(-scan_radius, scan_radius + 1):
        for z in range(-scan_radius, scan_radius + 1):
            for x in range(-scan_radius, scan_radius + 1):
                var block_position: Vector3i = center + Vector3i(x, y, z)
                if not Ref.world.is_position_loaded(block_position):
                    continue
                snapshot[block_position] = {
                    "block_id": int(Ref.world.get_block_type_at(block_position).id),
                    "fire_level": int(Ref.world.get_fire_at(block_position)),
                }
    return snapshot


func _broadcast_world_change_snapshot(before_snapshot: Dictionary) -> void:
    if Ref.coop_manager == null or not Ref.coop_manager.has_active_session() or not Ref.coop_manager.multiplayer.is_server():
        return

    var block_changes: Array = []
    var fire_changes: Array = []
    for block_position in before_snapshot.keys():
        var previous_state: Dictionary = before_snapshot[block_position]
        var current_block_id: int = int(Ref.world.get_block_type_at(block_position).id)
        var current_fire_level: int = int(Ref.world.get_fire_at(block_position))
        if current_block_id != int(previous_state.get("block_id", 0)):
            block_changes.append([block_position, current_block_id])
        if current_fire_level != int(previous_state.get("fire_level", 0)):
            fire_changes.append([block_position, current_fire_level])

    Ref.coop_manager.broadcast_host_world_changes(block_changes, fire_changes)


func explode_blocks() -> void:
    if not Ref.world.is_position_loaded(global_position):
        return

    if Ref.coop_manager != null and Ref.coop_manager.has_active_session() and not Ref.coop_manager._is_local_world_authority():
        return

    var before_snapshot: Dictionary = _capture_world_change_snapshot()
    if watery:
        Ref.world.flood_at(global_position, explode_radius)
    else:
        Ref.world.explode_at(global_position, explode_radius, firey)
    _broadcast_world_change_snapshot(before_snapshot)


func explode_entities() -> void:
    %EntityCast.shape = %EntityCast.shape.duplicate()
    %EntityCast.shape.radius = explode_radius
    %EntityCast.force_shapecast_update()

    var exploded: Array[Entity]
    for i in range(%EntityCast.get_collision_count()):
        var collider: Node3D = %EntityCast.get_collider(i)
        var to_explode: Entity
        if collider is PhysicsBody3D:
            to_explode = collider as Entity
            if not is_instance_valid(to_explode):
                to_explode = collider.owner as Entity
        if collider is Area3D:
            to_explode = collider.owner as Entity
        if exploded.find(to_explode) > -1:
            continue
        explode_entity(to_explode)
        exploded.append(to_explode)


func explode_visually() -> void:
    %AnimationPlayer.play("explode")
    await %AnimationPlayer.animation_finished


func explode() -> void:
    explode_blocks()
    explode_entities()
    await explode_visually()
    queue_free()


func explode_entity(target: Entity) -> void:
    if not is_instance_valid(target) or target.disabled or target.dead or not target.is_inside_tree():
        return
    if target.direct_damage_cooldown:
        return
    if not is_instance_valid(entity_owner):
        entity_owner = null
    if entity_owner == target and not attacks_self:
        return

    if firey and target.has_node("%Burn"):
        target.get_node("%Burn").ignite()

    var explode_vector: Vector3 = target.global_position - global_position
    var explosion_strength: float = sqrt(max(0.0, 1.0 - explode_vector.length() / float(explode_radius)))

    var hate: int = 0
    if is_instance_valid(entity_owner):
        hate = entity_owner.hate

    var actual_damage: int = max(1, round(max_damage * explosion_strength + hate * hate_scale))
    var knockback_direction: Vector3 = explode_vector.normalized()
    var knockback_vector: Vector3 = (knockback_boost + knockback_direction) * explosion_strength * knockback_strength

    target.knockback_velocity += knockback_vector

    if actual_damage > 0:
        target.attacked(entity_owner, actual_damage)

    if target.has_node("%Bleed"):
        target.get_node("%Bleed").bleed(target.head.global_position, -knockback_direction, actual_damage)
