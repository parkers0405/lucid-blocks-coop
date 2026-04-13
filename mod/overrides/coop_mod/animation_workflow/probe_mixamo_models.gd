@tool
extends SceneTree


func _init() -> void:
	_probe_scene("default", "res://coop_mod/animation_workflow/source_fbx/default_base/low_poly_character.fbx")
	_probe_scene("pim", "res://coop_mod/animation_workflow/source_fbx/pim_base/pim_mixamo_tpose.fbx")
	_probe_animation("res://coop_mod/animation_workflow/generated/mixamo_runtime/walk.res")
	quit()


func _probe_scene(label: String, path: String) -> void:
	var scene := load(path)
	if not (scene is PackedScene):
		print(label, "load_failed", path)
		return
	var root: Node = (scene as PackedScene).instantiate()
	var skeleton := _find_skeleton(root)
	if skeleton == null:
		print(label, "no_skeleton")
		root.queue_free()
		return
	print("scene", label, "root", root.name, "skeleton_path", root.get_path_to(skeleton), "bone_count", skeleton.get_bone_count())
	for i in range(min(30, skeleton.get_bone_count())):
		print(label, "bone", i, skeleton.get_bone_name(i))
	root.queue_free()


func _probe_animation(path: String) -> void:
	var anim := load(path) as Animation
	if anim == null:
		print("anim_failed", path)
		return
	print("anim_tracks", anim.get_track_count())
	for i in range(anim.get_track_count()):
		var track_type := anim.track_get_type(i)
		print("track", i, track_type, anim.track_get_path(i))


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
