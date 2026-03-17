class_name Heart extends Ball


func deal_damage(target: Entity) -> void:
	if not is_instance_valid(entity_owner):
		entity_owner = null

	if not is_instance_valid(target) or target.dead or linear_velocity.length() < minimum_attack_velocity:
		return
	if target == entity_owner:
		return

	var healing_power: int = max(1, roundi(attack_per_velocity * (previous_linear_velocity.length() - minimum_attack_velocity)))
	var heal_amount: int = -min(target.max_health - target.health, healing_power)
	if heal_amount == 0:
		return

	var knockback_delta: Vector3 = knockback_strength * previous_linear_velocity
	knockback_delta.y += knockback_strength * target.jump_modifier * knockback_vertical_strength * (0.5 if not target.is_on_floor() else 1.0)

	if Ref.coop_manager != null and multiplayer.is_server() and Ref.coop_manager.sync_host_direct_hit_on_remote_player(entity_owner, target, global_position, heal_amount, knockback_delta):
		_on_timeout()
		return

	target.set_deferred("knockback_velocity", target.knockback_velocity + knockback_delta)
	target.attacked(entity_owner, heal_amount)
	_on_timeout()
