class_name Attack extends Behavior

@export var damage: int = 1
@export var fire_aspect: bool = false

var damage_modifier: float = 1.0


func attack(target, damage_position: Vector3, knockback_strength: float = 22.0, fly_strength: float = 0.15) -> bool:
    if Ref.coop_manager != null and not multiplayer.is_server() and entity == Ref.player:
        target = Ref.coop_manager._resolve_client_attack_target(target)
    if not is_instance_valid(target) or entity.disabled or not enabled or target.dead or not is_inside_tree() or not target.is_inside_tree():
        return false

    var is_remote_player_target: bool = Ref.coop_manager != null and Ref.coop_manager.is_remote_player_proxy(target) and target != Ref.player
    if is_remote_player_target and not multiplayer.is_server():
        return true

    if target.direct_damage_cooldown:
        return false

    var horizontal_kb: Vector3 = target.global_position - entity.global_position
    horizontal_kb.y = 0
    horizontal_kb = horizontal_kb.normalized()

    var actual_damage: int = int(damage * damage_modifier)

    if not is_remote_player_target and target.axe_weakness and is_instance_valid(entity.held_item) and entity.held_item is HeldTool and entity.held_item.item.axe_boost:
        @warning_ignore("narrowing_conversion")
        actual_damage *= 1.5
    if not is_remote_player_target and target.pickaxe_weakness and entity.held_item is HeldTool and entity.held_item.item.pickaxe_boost:
        @warning_ignore("narrowing_conversion")
        actual_damage *= 1.5
    if not is_remote_player_target and target.cristella and entity.held_item is HeldTool and entity.held_item.item.cristella_boost:
        @warning_ignore("narrowing_conversion")
        actual_damage *= 2.5
    if not is_remote_player_target and target.slime and entity.held_item is HeldTool and entity.held_item.item.slime_boost:
        @warning_ignore("narrowing_conversion")
        actual_damage *= 2.5

    if is_remote_player_target:
        if target.has_method("begin_direct_damage_cooldown"):
            target.begin_direct_damage_cooldown()
        else:
            target.direct_damage_cooldown = true
            var direct_damage_timer := target.get_node_or_null("DirectDamageTimer") as Timer
            if direct_damage_timer != null:
                direct_damage_timer.start()

        if Ref.coop_manager != null and Ref.coop_manager.sync_host_attack_on_remote_player(entity, target, damage_position, actual_damage, knockback_strength, fly_strength, fire_aspect):
            if entity.held_item != null and entity.held_item.item is Tool:
                entity.decrease_held_item_durability(1)
            return true
        return false

    var should_sync_local_entity_attack: bool = entity == Ref.player \
        and not multiplayer.is_server() \
        and Ref.coop_manager != null \
        and target is Entity \
        and not (target is Player) \
        and not Ref.coop_manager.is_remote_player_proxy(target)
    if should_sync_local_entity_attack:
        return Ref.coop_manager.sync_local_attack_on_entity(entity, target, damage_position, actual_damage, knockback_strength, fly_strength, fire_aspect)

    var attacker_velocity: Vector3 = entity.velocity
    if Ref.coop_manager != null and Ref.coop_manager.has_connected_remote_peers():
        attacker_velocity = Ref.coop_manager.get_attack_impulse_velocity(entity)
    target.knockback_velocity += 0.45 * attacker_velocity + horizontal_kb * knockback_strength
    target.knockback_velocity.y += knockback_strength * target.jump_modifier * fly_strength * (0.5 if not target.is_on_floor() else 1.0)
    target.attacked(entity, actual_damage)

    if entity.held_item != null and entity.held_item.item is Tool:
        entity.decrease_held_item_durability(1)

    if fire_aspect and target.has_node("%Burn"):
        target.get_node("%Burn").ignite()

    if target.has_node("%Bleed"):
        var target_to_attacker: Vector3 = (entity.global_position - target.global_position).normalized()
        target.get_node("%Bleed").bleed(damage_position, target_to_attacker, actual_damage)

    return true
