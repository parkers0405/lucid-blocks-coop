@tool
extends SceneTree


func _init() -> void:
	var scene := load("res://coop_mod/animation_workflow/source_fbx/pim_base/pim_sketchfab.fbx")
	if not (scene is PackedScene):
		print("failed")
		quit(1)
		return
	var root: Node = (scene as PackedScene).instantiate()
	var skeleton := _find_skeleton(root)
	if skeleton == null:
		print("no skeleton")
		quit(1)
		return
	for bone_name in ["hips", "spine", "spine1", "neck", "head", "upperarm.L", "upperarm.R"]:
		var idx := skeleton.find_bone(bone_name)
		if idx == -1:
			print("missing %s" % bone_name)
			continue
		var rest: Transform3D = skeleton.get_bone_rest(idx)
		print("%s rest_origin=%s rest_basis=%s" % [bone_name, rest.origin, rest.basis])
	root.queue_free()
	quit()


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
