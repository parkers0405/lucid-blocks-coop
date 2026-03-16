extends SceneTree


func _init() -> void:
	var scene_paths := [
		"res://main/entity/player/player.tscn",
		"res://main/entity/manikin/manikin.tscn",
		"res://main/items/dropped_item/dropped_item.tscn",
	]

	for scene_path in scene_paths:
		print("=== ", scene_path, " ===")
		var scene := load(scene_path)
		if scene == null:
			print("FAILED_LOAD")
			continue
		if not (scene is PackedScene):
			print("NOT_PACKED_SCENE: ", typeof(scene))
			continue

		var node := scene.instantiate()
		if node == null:
			print("FAILED_INSTANTIATE")
			continue

		print("ROOT_NAME: ", node.name)
		print("ROOT_CLASS: ", node.get_class())
		_print_node_tree(node, 0, 3)
		node.free()

	quit()


func _print_node_tree(node: Node, depth: int, max_depth: int) -> void:
	if depth > max_depth:
		return
	var indent := "  ".repeat(depth)
	print(indent, node.name, " [", node.get_class(), "]")
	for child in node.get_children():
		_print_node_tree(child, depth + 1, max_depth)
