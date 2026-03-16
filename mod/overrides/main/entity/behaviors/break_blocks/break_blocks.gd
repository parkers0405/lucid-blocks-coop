class_name BreakBlocks extends Behavior

@export var decrease_held_item_durability: bool = true
@export var axe: bool = false
@export var axe_break_speed_multiplier: float = 1.0
@export var pickaxe: bool = false
@export var pickaxe_break_speed_multiplier: float = 1.0
@export var shovel: bool = false
@export var shovel_break_speed_multiplier: float = 1.0
@export var meat: bool = false
@export var meat_break_speed_multiplier: float = 1.0
@export var plant: bool = false
@export var plant_break_speed_multiplier: float = 1.0
@export var break_block_outline_scene: PackedScene = preload("res://main/entity/behaviors/break_blocks/break_block_outline.tscn")
@export var place_effect_scene: PackedScene = preload("res://main/world/rendering/place_effect/place_effect.tscn")
@export var dropped_item_scene: PackedScene = preload("res://main/items/dropped_item/dropped_item.tscn")

signal block_broken

var progress: float = 0.0
var progress_speed: float = 1.0
var progress_goal: float = 1.0
var active_position: Vector3i
var block: Block
var breaking: bool = false
var break_outline: BreakBlockOutline


func _ready() -> void :
    super._ready()
    block_broken.connect(_on_block_broken)
    set_process(false)


func _on_block_broken() -> void :
    break_block_instant(active_position)
    break_block_stop()


func _on_progress_effect() -> void :
    var new_effect: PlaceEffect = place_effect_scene.instantiate()
    get_tree().get_root().add_child(new_effect)
    new_effect.global_position = Vector3(active_position)
    new_effect.initialize(block, -12.0)


func drop_item() -> void :
    if Ref.coop_manager != null and Ref.coop_manager.is_client_synced_entity(entity):
        return
    if block.pickaxe_required and not pickaxe:
        return
    if block.axe_required and not axe:
        return
    var to_drop: Array[ItemState] = []

    if block.drop_item == null and block.drop_loot == null:
        if not block.can_drop:
            return

        var new_state: ItemState = ItemState.new()
        new_state.initialize(block)
        new_state.count = 1
        to_drop.append(new_state)
    if block.drop_item != null:
        var new_state: ItemState = ItemState.new()
        new_state.initialize(block.drop_item)
        new_state.count = 1
        to_drop.append(new_state)
    if block.drop_loot != null:
        to_drop.append_array(block.drop_loot.realize())

    for item_state in to_drop:
        var new_item: DroppedItem = dropped_item_scene.instantiate()
        if len(to_drop) > 1:
            new_item.delay_merge()
        get_tree().get_root().add_child(new_item)
        new_item.global_position = Vector3(active_position)
        new_item.initialize(item_state)


func break_block_instant(block_position: Vector3i) -> void :
    if entity.disabled or not enabled:
        return
    if Ref.coop_manager != null and Ref.coop_manager.is_client_synced_entity(entity):
        return

    if (Ref.world.is_position_loaded(block_position) and not Ref.world.get_block_type_at(block_position).id == 0) or Ref.world.get_block_type_at(block_position).internal_name == "cutscene block":
        active_position = block_position
        block = ItemMap.map(Ref.world.get_block_type_at(block_position).id)

        if entity == Ref.player and Ref.coop_manager != null and Ref.coop_manager.sync_local_block_break(self, block_position):
            return

        var held_item: ItemState = entity.held_item_inventory.items[entity.held_item_index]
        if decrease_held_item_durability and not (entity == Ref.player and held_item != null and ItemMap.map(held_item.id).internal_name == "super drill"):
            if block.pickaxe_affinity and pickaxe or block.axe_affinity and axe or block.shovel_affinity and shovel or block.meat_affinity and meat or block.plant_affinity and plant:
                entity.decrease_held_item_durability(1)
        if entity == Ref.player:
            Steamworks.increment_statistic("blocks_broken")
        Ref.world.break_block_at(block_position, true, Ref.main.creative and entity == Ref.player)
        drop_item()

        if entity == Ref.player and Ref.coop_manager != null:
            Ref.coop_manager.broadcast_host_block_break(block_position)


func break_block_start(block_position: Vector3i) -> void :
    if Ref.coop_manager != null and Ref.coop_manager.is_client_synced_entity(entity):
        return
    if not Ref.world.is_position_loaded(block_position) or Ref.world.get_block_type_at(block_position).id == 0 or (Ref.world.get_block_type_at(block_position).unbreakable and not Ref.main.creative):
        return
    if breaking:
        break_block_stop()
    progress = 0.0

    active_position = block_position
    block = ItemMap.map(Ref.world.get_block_type_at(active_position).id)

    break_outline = break_block_outline_scene.instantiate()
    break_outline.progress_effect.connect(_on_progress_effect)
    break_outline.update_block(block)
    get_tree().get_root().add_child(break_outline)
    break_outline.global_position = Vector3(block_position) + Vector3(0.5, 0.5, 0.5)

    progress_goal = block.break_time

    var held_item: ItemState = entity.held_item_inventory.items[entity.held_item_index]
    if block.break_time <= 0 or (entity == Ref.player and held_item != null and ItemMap.map(held_item.id).internal_name == "super drill"):
        progress = progress_goal

    breaking = true
    set_process(true)


func break_block_stop() -> void :
    if not entity.disabled and enabled and not progress >= progress_goal and progress_goal - progress < 0.1:
        progress = progress_goal + 1.0
        block_broken.emit()
        return
    breaking = false
    if is_instance_valid(break_outline):
        break_outline.queue_free()
    progress = 0.0
    set_process(false)


func _process(delta: float) -> void :
    if breaking and not entity.disabled and enabled:
        progress_speed = 1.0
        if block.axe_affinity:
            progress_speed = max(progress_speed, axe_break_speed_multiplier)
        if block.pickaxe_affinity:
            progress_speed = max(progress_speed, pickaxe_break_speed_multiplier)
        if block.plant_affinity:
            progress_speed = max(progress_speed, plant_break_speed_multiplier)
        if block.meat_affinity:
            progress_speed = max(progress_speed, meat_break_speed_multiplier)
        if block.shovel_affinity:
            progress_speed = max(progress_speed, shovel_break_speed_multiplier)
        progress += delta * progress_speed
        break_outline.update_progress(progress / progress_goal)
        if progress >= progress_goal:
            block_broken.emit()
