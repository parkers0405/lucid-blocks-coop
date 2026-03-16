class_name Comet extends Area3D

@export var explosion_scene: PackedScene
@export var speed: float = 9.0

var entity_owner: Entity
var exploding: bool = false
var direction: Vector3

func _ready() -> void :
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Object) -> void :
    if body is Yhvh:
        return
    explode(global_position)

func _physics_process(delta: float) -> void :
    if exploding:
        speed = lerp(speed, 0.0, clamp(delta * 7.0, 0.0, 1.0))
    global_position += speed * delta * direction
    var max_distance: float = global_position.distance_to(Ref.player.global_position)
    if Ref.coop_manager != null and Ref.coop_manager.has_connected_remote_peers():
        max_distance = Ref.coop_manager.get_nearest_session_player_distance(global_position, max_distance)
    if max_distance > 200.0:
        queue_free()
    rotation += delta * speed * Vector3(0.1, 0.4, 0.12)

func shoot(start: Vector3, new_direction: Vector3) -> void :
    global_position = start
    direction = new_direction
    SpatialMath.look_at_local(self, direction)

func explode(hit_point: Vector3) -> void :
    if exploding:
        return
    exploding = true
    %AnimationPlayer.play("explode")
    await get_tree().create_timer(0.12, false).timeout

    var explosion: Explosion = explosion_scene.instantiate()
    get_tree().get_root().add_child(explosion)
    explosion.entity_owner = entity_owner
    explosion.global_position = hit_point
    explosion.explode()

    if %AnimationPlayer.is_playing():
        await %AnimationPlayer.animation_finished

    queue_free()
