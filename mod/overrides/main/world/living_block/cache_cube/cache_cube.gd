class_name CacheCube extends LivingBlock

@export_enum("cache cube", "cabinet", "hopper") var style: int

var styles: Array[int] = [GameMenu.STYLE_CACHE_CUBE, GameMenu.STYLE_CABINET, GameMenu.STYLE_HOPPER]
var open: bool = false
var broken: bool = false


func _ready() -> void:
    var inventory: Inventory = %Inventory
    if inventory != null and not inventory.refresh.is_connected(_on_inventory_refreshed):
        inventory.refresh.connect(_on_inventory_refreshed)


func _on_inventory_refreshed(_index: int) -> void:
    if Ref.coop_manager != null:
        Ref.coop_manager.notify_local_storage_inventory_changed(Vector3i(global_position), %Inventory)


func interact(interactor: Entity) -> void:
    if not can_currently_interact(interactor):
        return
    super.interact(interactor)

    open = true
    InventorySlot.cache_cube_inventory = %Inventory
    %OpenSound.play()

    Ref.game_menu.initialize_cache_cube_inventory(%Inventory)
    Ref.game_menu.open_inventory(GameMenu.INVENTORY_CACHE_CUBE, styles[style])

    await Ref.game_menu.inventory_closed

    InventorySlot.cache_cube_inventory = null
    if Ref.coop_manager != null:
        Ref.coop_manager.notify_local_storage_inventory_changed(Vector3i(global_position), %Inventory)

    if has_node("%CloseSound"):
        %CloseSound.play()

    open = false


func before_breaking() -> void:
    broken = true
    if open:
        Ref.game_menu.close_inventory(true)
    open = false
    drop_block_items(%Inventory, global_position, get_tree())


func before_unloading() -> void:
    if open:
        Ref.game_menu.close_inventory(true)
    open = false


static func drop_block_items(inventory: Inventory, block_position: Vector3, tree: SceneTree) -> void:
    const break_offset: float = 0.55
    const throw_speed: float = 5.0
    const break_spread: float = 1.0
    const break_spawn_spread: float = 1.0

    var dropped_item_scene: PackedScene = preload("res://main/items/dropped_item/dropped_item.tscn")
    for item_state in inventory.items:
        if not item_state:
            continue

        var new_item: DroppedItem = dropped_item_scene.instantiate()
        new_item.delay_collect()
        tree.get_root().add_child(new_item)
        new_item.global_position = block_position + Vector3(0.0, break_offset, 0.0) + Vector3(randf() - 0.5, 0.0, randf() - 0.5) * break_spawn_spread
        new_item.initialize(item_state)

        if new_item.state != DroppedItem.SWIM:
            new_item.velocity = throw_speed * (Vector3(0, 1, 0) + Vector3(randf() - 0.5, 0.0, randf() - 0.5) * break_spread).normalized()
