class_name Attack extends Behavior

@export var damage: int = 1
@export var fire_aspect: bool = false

var damage_modifier: float = 1.0


func attack(target: Entity, damage_position: Vector3, knockback_strength: float = 22.0, fly_strength: float = 0.15) -> bool:
    if not is_instance_valid(target) or entity.disabled or not enabled or target.dead or not is_inside_tree() or not target.is_inside_tree():
        return false

    if entity == Ref.player and Ref.coop_manager != null and Ref.coop_manager.sync_local_entity_attack(self, target, damage_position, knockback_strength, fly_strength):
        return true

    if target.direct_damage_cooldown:
        return false

    var horizontal_kb: Vector3 = target.global_position - entity.global_position
    horizontal_kb.y = 0
    horizontal_kb = horizontal_kb.normalized()

    var actual_damage: int = int(damage * damage_modifier)

    if target.axe_weakness and is_instance_valid(entity.held_item) and entity.held_item is HeldTool and entity.held_item.item.axe_boost:
        @warning_ignore("narrowing_conversion")
        actual_damage *= 1.5
    if target.pickaxe_weakness and entity.held_item is HeldTool and entity.held_item.item.pickaxe_boost:
        @warning_ignore("narrowing_conversion")
        actual_damage *= 1.5
    if target.cristella and entity.held_item is HeldTool and entity.held_item.item.cristella_boost:
        @warning_ignore("narrowing_conversion")
        actual_damage *= 2.5
    if target.slime and entity.held_item is HeldTool and entity.held_item.item.slime_boost:
        @warning_ignore("narrowing_conversion")
        actual_damage *= 2.5

    if Ref.coop_manager != null and Ref.coop_manager.is_remote_player_proxy(target):
        target.direct_damage_cooldown = true
        var direct_damage_timer = target.get_node_or_null("%DirectDamageTimer") as Timer
        if direct_damage_timer != null:
            direct_damage_timer.start()

        if Ref.coop_manager.sync_host_attack_on_remote_player(entity, target, damage_position, actual_damage, knockback_strength, fly_strength, fire_aspect):
            if entity.held_item != null and entity.held_item.item is Tool:
                entity.decrease_held_item_durability(1)
            return true

    var health_before: int = target.health
    target.knockback_velocity += 0.45 * entity.velocity + horizontal_kb * knockback_strength
    target.knockback_velocity.y += (knockback_strength * target.jump_modifier * fly_strength * (0.5 if not target.is_on_floor() else 1.0))
    target.attacked(entity, actual_damage)

    if target == Ref.player and Ref.coop_manager != null and Ref.coop_manager.is_client_session() and target.health == health_before:
        Ref.coop_manager.play_local_damage_feedback(actual_damage)

    if entity.held_item != null and entity.held_item.item is Tool:
        entity.decrease_held_item_durability(1)

    if fire_aspect and target.has_node("%Burn"):
        target.get_node("%Burn").ignite()

    if target.has_node("%Bleed"):
        var target_to_attacker = (entity.global_position - target.global_position).normalized()
        target.get_node("%Bleed").bleed(damage_position, target_to_attacker, actual_damage)

    return true
