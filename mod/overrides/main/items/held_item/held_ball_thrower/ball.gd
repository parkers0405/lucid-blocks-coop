class_name Ball extends RigidBody3D

@export var lifetime: float = 15.0
@export var self_protection_time: float = 1.0
@export var minimum_attack_velocity: float = 3.0
@export var attack_per_velocity: float = 0.2
@export var knockback_strength: float = 0.55
@export var knockback_vertical_strength: float = 0.16
@export var same_attack_delay: float = 0.2
@export var can_parry: bool = true
@export var destroy_loot: Loot
@export var dropped_item_scene: PackedScene = preload("res://main/items/dropped_item/dropped_item.tscn")

var last_attacked: Entity
var entity_owner: Entity
var previous_linear_velocity: Vector3
var frames_active: int = 0
var deleting: bool = false


func _get_coop_intended_remote_peer_id() -> int:
	if has_meta("coop_intended_peer_id"):
		return int(get_meta("coop_intended_peer_id", -1))
	if is_instance_valid(entity_owner) and entity_owner.has_method("get_coop_locked_target_peer_id"):
		return int(entity_owner.call("get_coop_locked_target_peer_id"))
	return -1


func _should_ignore_target_for_coop_locked_peer(target: Entity) -> bool:
	if target == null or not is_instance_valid(target) or Ref.coop_manager == null:
		return false
	var intended_peer_id := _get_coop_intended_remote_peer_id()
	if intended_peer_id <= 1:
		return false
	if target == Ref.player:
		return true
	if Ref.coop_manager.is_remote_player_proxy(target):
		return Ref.coop_manager.get_remote_player_proxy_peer_id(target) != intended_peer_id
	return false


func _ready() -> void:
	%LifeTimer.start(lifetime)
	%LifeTimer.timeout.connect(_on_timeout)
	%DelayTimer.timeout.connect(_on_delay_timeout)
	%HurtArea3D.body_entered.connect(_on_body_entered)
	%HurtArea3D.area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_self_entered)


func _on_body_self_entered(_body: Node) -> void:
	if frames_active <= 2:
		return
	%BouncePlayer.play()


func _on_delay_timeout() -> void:
	if not is_inside_tree():
		return
	%TrailParticles.emitting = true


func _on_area_entered(area: Area3D) -> void:
	if not is_instance_valid(area):
		return
	deal_damage(area.owner as Entity)


func _on_body_entered(_body: Node) -> void:
	pass


func deal_damage(target: Entity) -> void:
	if not is_instance_valid(entity_owner):
		entity_owner = null

	if not is_instance_valid(target) or target.dead or linear_velocity.length() < minimum_attack_velocity:
		return
	if _should_ignore_target_for_coop_locked_peer(target):
		return
	if target == entity_owner and lifetime - %LifeTimer.time_left < self_protection_time:
		return
	if target == last_attacked and not %SameAttackTimer.is_stopped():
		return

	var damage: int = roundi(attack_per_velocity * (previous_linear_velocity.length() - minimum_attack_velocity))
	if damage <= 0:
		return

	var knockback_delta: Vector3 = knockback_strength * previous_linear_velocity
	knockback_delta.y += knockback_strength * target.jump_modifier * knockback_vertical_strength * (0.5 if not target.is_on_floor() else 1.0)
	if is_instance_valid(entity_owner) and entity_owner.get_class() == "Manikin":
		print("[lucid-blocks-coop][manikin-debug] ball-hit target=", target.name, ":", target.get_class(), " owner=", entity_owner.name, " vel=", previous_linear_velocity)

	if Ref.coop_manager != null and multiplayer.is_server() and Ref.coop_manager.sync_host_direct_hit_on_remote_player(entity_owner, target, global_position, damage, knockback_delta):
		%SameAttackTimer.start(same_attack_delay)
		last_attacked = target
		return

	target.set_deferred("knockback_velocity", target.knockback_velocity + knockback_delta)
	target.attacked(entity_owner, damage)
	if target.has_node("%Bleed"):
		var target_to_attacker: Vector3 = (global_position - target.global_position).normalized()
		target.get_node("%Bleed").bleed(global_position, target_to_attacker, damage)

	%SameAttackTimer.start(same_attack_delay)
	last_attacked = target


func _on_timeout() -> void:
	if deleting:
		return
	deleting = true

	if is_instance_valid(destroy_loot):
		var items: Array[ItemState] = destroy_loot.realize()
		for item in items:
			if item == null:
				continue
			var new_item: DroppedItem = dropped_item_scene.instantiate()
			get_tree().get_root().add_child(new_item)
			new_item.global_position = global_position
			new_item.delay_merge()
			new_item.initialize(item)

	%TrailParticles.emitting = false
	%AnimationPlayer.play("delete")
	await %AnimationPlayer.animation_finished
	queue_free()


func _physics_process(_delta: float) -> void:
	previous_linear_velocity = linear_velocity
	frames_active += 1


func attacked() -> void:
	%BouncePlayer.play()
	%HitPlayer.play()
	%Sparks.emitting = true
