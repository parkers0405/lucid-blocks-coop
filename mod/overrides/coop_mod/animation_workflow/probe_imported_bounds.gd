@tool
extends SceneTree


func _init() -> void:
	_probe("default", "res://coop_mod/animation_workflow/source_fbx/default_base/low_poly_character.fbx")
	_probe("pim", "res://coop_mod/animation_workflow/source_fbx/pim_base/pim_mixamo_tpose.fbx")
	quit()


func _probe(label: String, path: String) -> void:
	var scene := load(path)
	if not (scene is PackedScene):
		print(label, "load_failed")
		return
	var root := (scene as PackedScene).instantiate() as Node3D
	if root == null:
		print(label, "root_failed")
		return
	var bounds := _get_imported_avatar_bounds(root)
	print(label, "bounds_pos", bounds.position, "bounds_size", bounds.size)
	root.queue_free()


func _get_imported_avatar_bounds(root: Node3D) -> AABB:
	var mesh_bounds: Array = []
	_collect_imported_mesh_bounds(root, Transform3D.IDENTITY, mesh_bounds, true)
	if mesh_bounds.is_empty():
		return AABB(Vector3(-0.35, 0.0, -0.35), Vector3(0.7, 1.7, 0.7))

	var merged: AABB = mesh_bounds[0]
	for index in range(1, mesh_bounds.size()):
		merged = merged.merge(mesh_bounds[index])
	return merged


func _collect_imported_mesh_bounds(node: Node, parent_transform: Transform3D, mesh_bounds: Array, skip_node_transform: bool = false) -> void:
	var current_transform: Transform3D = parent_transform
	if node is Node3D and not skip_node_transform:
		current_transform = parent_transform * (node as Node3D).transform

	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			mesh_bounds.append(_transform_aabb(mesh_node.get_aabb(), current_transform))

	for child in node.get_children():
		_collect_imported_mesh_bounds(child, current_transform, mesh_bounds, false)


func _transform_aabb(source_aabb: AABB, transform: Transform3D) -> AABB:
	var corners: Array = [
		source_aabb.position,
		source_aabb.position + Vector3(source_aabb.size.x, 0.0, 0.0),
		source_aabb.position + Vector3(0.0, source_aabb.size.y, 0.0),
		source_aabb.position + Vector3(0.0, 0.0, source_aabb.size.z),
		source_aabb.position + Vector3(source_aabb.size.x, source_aabb.size.y, 0.0),
		source_aabb.position + Vector3(source_aabb.size.x, 0.0, source_aabb.size.z),
		source_aabb.position + Vector3(0.0, source_aabb.size.y, source_aabb.size.z),
		source_aabb.position + source_aabb.size,
	]

	var first_corner: Vector3 = transform * corners[0]
	var transformed_aabb := AABB(first_corner, Vector3.ZERO)
	for index in range(1, corners.size()):
		transformed_aabb = transformed_aabb.expand(transform * corners[index])
	return transformed_aabb
