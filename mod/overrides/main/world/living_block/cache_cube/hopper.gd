class_name Hopper extends CacheCube

@export var check_stutter: float = 0.1
@export var check_time: float = 0.5
@onready var shape: ShapeCast3D = %ItemShape


func _ready() -> void:
    super._ready()
    %CollectTimer.timeout.connect(_on_timeout)
    %CollectTimer.start(check_time + randf_range(-check_stutter, check_stutter))


func _on_timeout() -> void:
    %CollectTimer.start(check_time + randf_range(-check_stutter, check_stutter))

    if disabled or not Ref.world.is_position_loaded(global_position) or not has_node("%Inventory"):
        return

    shape.force_shapecast_update()

    for i in range(shape.get_collision_count()):
        var body: Object = shape.get_collider(i)
        if not is_instance_valid(body):
            continue
        var dropped_item: DroppedItem = body.get_parent() as DroppedItem
        if not is_instance_valid(dropped_item) or not dropped_item.can_collect:
            continue
        var remaining_item: ItemState = %Inventory.accept(dropped_item.item, true)

        if remaining_item == null:
            dropped_item.collect()
