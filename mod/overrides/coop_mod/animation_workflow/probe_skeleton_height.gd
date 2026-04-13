@tool
extends SceneTree


func _init() -> void:
	_probe("default", "res://coop_mod/animation_workflow/source_fbx/default_base/low_poly_character.fbx", ["Head", "LeftFoot", "RightFoot"])
	_probe("pim", "res://coop_mod/animation_workflow/source_fbx/pim_base/pim_mixamo_tpose.fbx", ["head", "foot.L", "foot.R"])
	quit()


func _probe(label: String, path: String, bones: Array[String]) -> void:
	var scene := load(path)
	if not (scene is PackedScene):
		print(label, "load_failed")
		return
	var root: Node = (scene as PackedScene).instantiate()
	var skeleton := _find_skeleton(root)
	if skeleton == null:
		print(label, "no_skeleton")
		return
	var head_idx := skeleton.find_bone(bones[0])
	var left_idx := skeleton.find_bone(bones[1])
	var right_idx := skeleton.find_bone(bones[2])
	print(label, "indices", head_idx, left_idx, right_idx)
	if head_idx == -1 or left_idx == -1 or right_idx == -1:
		return
	var head_pos := _global_rest_origin(skeleton, head_idx)
	var left_pos := _global_rest_origin(skeleton, left_idx)
	var right_pos := _global_rest_origin(skeleton, right_idx)
	var foot_mid := (left_pos + right_pos) * 0.5
	print(label, "head", head_pos, "foot_mid", foot_mid, "distance", head_pos.distance_to(foot_mid))


func _global_rest_origin(skeleton: Skeleton3D, bone_idx: int) -> Vector3:
	var transform := skeleton.get_bone_rest(bone_idx)
	var parent_idx := skeleton.get_bone_parent(bone_idx)
	while parent_idx != -1:
		transform = skeleton.get_bone_rest(parent_idx) * transform
		parent_idx = skeleton.get_bone_parent(parent_idx)
	return transform.origin


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
