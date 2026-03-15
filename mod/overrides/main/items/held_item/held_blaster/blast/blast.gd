class_name Blast extends Node3D

@export var blast_strength: float = 1.0
@export var speed: float = 16.0
@onready var area: Area3D = %CrashArea
@onready var blast_area: ShapeCast3D = %BlastArea
@onready var ray: RayCast3D = %CrashRay
@onready var anim: AnimationPlayer = %AnimationPlayer
@onready var life_timer: Timer = %Timer

var velocity: Vector3
var exploding: bool = false
var blast_things: Array[Entity]


func _ready() -> void :
	area.body_entered.connect(_on_body_entered)
	area.area_entered.connect(_on_body_entered)
	%Blast.set_instance_shader_parameter("rand", randf())
	%Mesh.set_instance_shader_parameter("rand", randf())
	life_timer.timeout.connect(queue_free)


func _on_body_entered(_body: Node3D) -> void :
	explode.call_deferred()


func _on_area_entered(_other_area: Area3D) -> void :
	explode.call_deferred()


func shoot(initial_velocity: Vector3, initial_direction: Vector3) -> void :
	if not exploding:
		velocity = initial_velocity + initial_direction * speed
	SpatialMath.look_at_local( %RotationPivot, velocity.normalized())


func _physics_process(delta: float) -> void :
	if exploding:
		return
	ray.target_position = ray.to_local(global_position + velocity * delta)
	ray.force_raycast_update()
	if ray.is_colliding():
		global_position = ray.get_collision_point()
		explode.call_deferred()
	elif _is_world_position_available(global_position) and Ref.world.is_block_solid_at(global_position):
		explode.call_deferred()
	else:
		global_position += velocity * delta


func explode() -> void :
	if exploding:
		return
	velocity = Vector3()
	exploding = true
	blast_area.force_shapecast_update()
	for i in blast_area.get_collision_count():
		var thing: Object = blast_area.get_collider(i)
		var multiplier: float = 1.0
		if thing is Entity:
			multiplier = thing.gravity_direction_multiplier
			var displacement: Vector3 = thing.global_position - global_position
			var distance: float = displacement.length()
			var direction: Vector3 = (Vector3(0, 2, 0) + displacement).normalized()
			thing.knockback_velocity += (Vector3(1, multiplier, 1) * blast_strength * direction / (0.3 + distance * 0.2) / thing.weight)
			if multiplier * thing.gravity_velocity.y < 0:
				thing.gravity_velocity.y *= 0.01
				thing.gravity_velocity.y += multiplier * 3.0 * (0.3 + distance * 0.2) / thing.weight
	anim.play("explode")
	await anim.animation_finished
	queue_free()


func _is_world_position_available(pos: Vector3) -> bool:
	return is_instance_valid(Ref.world) and Ref.world.is_position_loaded(pos)
