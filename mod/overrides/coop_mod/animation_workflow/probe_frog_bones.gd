@tool
extends SceneTree
func _init() -> void:
    var scene = load("res://coop_mod/animation_workflow/source_fbx/mr_frog_base/mr_frog_tpose.fbx")
    var root = (scene as PackedScene).instantiate()
    var skel: Skeleton3D = null
    for child in root.get_children():
        if child is Skeleton3D:
            skel = child
            break
    for i in range(skel.get_bone_count()):
        print("bone", i, skel.get_bone_name(i))
    root.queue_free()
    quit()
