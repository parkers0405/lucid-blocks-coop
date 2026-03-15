@icon("res://icons/living_block.svg")
class_name LivingBlock extends Node3D

@export var can_interact: bool = true
@export var player_interact_only: bool = true

var disabled: bool = false


func can_currently_interact(interactor: Entity) -> bool:
	if not can_interact or disabled:
		return false
	if not is_instance_valid(Ref.world) or not Ref.world.is_position_loaded(global_position):
		return false
	# Allow any player entity to interact, not just Ref.player (host).
	# In coop, Ref.player is always the local player. The guest's Ref.player
	# is the guest themselves, so this check naturally works for both.
	if player_interact_only and not (interactor is Player):
		return false
	return true


func interact(interactor: Entity) -> void :
	if not can_currently_interact(interactor):
		return
	Ref.world.modify_chunk(global_position)


func before_breaking() -> void :
	pass


func before_unloading() -> void :
	pass


func generate(_block_type: Block) -> void :
	pass


func preserve_save(file: SaveFile, uuid: String) -> void :
	file.set_data("node/%s/global_position" % uuid, global_position)
	for child in find_children("*"):
		if "preserve_save" in child:
			child.preserve_save(file, uuid)


func preserve_load(file: SaveFile, uuid: String) -> void :
	global_position = file.get_data("node/%s/global_position" % uuid, Vector3())
	register()
	for child in find_children("*"):
		if "preserve_load" in child:
			child.preserve_load(file, uuid)


func register() -> void :
	if not is_instance_valid(Ref.world):
		queue_free()
		return
	if not Ref.world.is_position_loaded(global_position) and not Ref.world.is_position_loading(global_position):
		queue_free()
		return
	Ref.world.register_living_block(global_position, self)
	tree_exiting.connect(_on_tree_exiting)


func _on_tree_exiting() -> void :
	before_unloading()
	if is_instance_valid(Ref.world):
		Ref.world.unregister_living_block(global_position)
