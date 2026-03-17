class_name PickUpItems extends Behavior

@export var inventory_priority: Inventory
@export var inventory_secondary: Inventory
@export var dropped_item_scene: PackedScene = preload("res://main/items/dropped_item/dropped_item.tscn")
@export var shape: Shape3D
@export var blocks_only: bool = false


func _ready() -> void:
    super._ready()
    %ItemArea3D.area_entered.connect(_on_dropped_item_entered)
    %CollisionShape3D.shape = shape
    %RefreshTimer.timeout.connect(_on_refresh_timer)
    assert(is_instance_valid(inventory_priority))


func _on_refresh_timer() -> void:
    %CollisionShape3D.disabled = true
    await get_tree().process_frame
    %CollisionShape3D.disabled = false


func _try_collect_with_coop_animation(dropped_item: DroppedItem) -> void:
    if Ref.coop_manager != null and Ref.coop_manager.has_method("play_local_host_drop_collect_animation"):
        if Ref.coop_manager.play_local_host_drop_collect_animation(entity, dropped_item):
            return
    dropped_item.collect()


func _on_dropped_item_entered(area: Area3D) -> void:
    if not enabled or entity.dead or entity.disabled:
        return
    if not area.get_parent() is DroppedItem:
        return
    var dropped_item: DroppedItem = area.get_parent() as DroppedItem

    if blocks_only and not ItemMap.map(dropped_item.item.id) is Block:
        return
    if not dropped_item.can_collect:
        return
    assert(not Ref.main.debug or dropped_item.item.count > 0)

    if is_instance_valid(inventory_secondary):
        var remaining_item: ItemState = inventory_priority.accept(dropped_item.item, false)

        if remaining_item != null:
            remaining_item = inventory_secondary.accept(remaining_item, false)

        if remaining_item != null:
            remaining_item = inventory_priority.accept(remaining_item)

        if remaining_item != null:
            remaining_item = inventory_secondary.accept(remaining_item)

        if remaining_item == null:
            _try_collect_with_coop_animation(dropped_item)
    else:
        var remaining_item: ItemState = inventory_priority.accept(dropped_item.item)

        if remaining_item == null:
            _try_collect_with_coop_animation(dropped_item)


func accept_item(item_state: ItemState, override_disable: bool = false) -> void:
    var remaining_item: ItemState

    if is_instance_valid(inventory_secondary):
        remaining_item = inventory_priority.accept(item_state, false)

        if remaining_item != null:
            remaining_item = inventory_secondary.accept(remaining_item, false)

        if remaining_item != null:
            remaining_item = inventory_priority.accept(remaining_item)

        if remaining_item != null:
            remaining_item = inventory_secondary.accept(remaining_item)
    else:
        remaining_item = inventory_priority.accept(item_state)

    if remaining_item != null and entity.has_node("%DropItems"):
        entity.get_node("%DropItems").drop_item(remaining_item, override_disable)
