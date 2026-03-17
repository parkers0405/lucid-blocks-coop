class_name SunBox extends MeshInstance3D

@export var default_texture: Texture2D
@export var wrath_texture: Texture2D
@onready var offset: Marker3D = %SunBoxOffset


func _ready() -> void :
    process_mode = Node.PROCESS_MODE_ALWAYS
    Ref.main.world_loaded.connect(_on_world_loaded)


func _on_world_loaded() -> void :
    material_override.set_shader_parameter("sun_texture", wrath_texture if Ref.main.wrathful_torus else default_texture)
    visible = Ref.world.current_dimension != LucidBlocksWorld.Dimension.CREATIVE and Ref.world.current_dimension != LucidBlocksWorld.Dimension.FIRMAMENT and Ref.world.current_dimension != LucidBlocksWorld.Dimension.YHVH


func _process(_delta: float) -> void :
    if is_instance_valid(Ref.player_camera):
        offset.global_position = Ref.player_camera.global_position
    else:
        offset.global_position = Ref.player.global_position

    var angle: float = (Ref.sun.time * PI * 2.0) + PI * 0.5
    var spin := Quaternion(Vector3.UP, angle)
    var tilt := Quaternion(Vector3.RIGHT, deg_to_rad(30.0))
    var q := spin * tilt
    rotation = q.get_euler()
