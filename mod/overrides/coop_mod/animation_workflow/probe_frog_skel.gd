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
    var head_idx = skel.find_bone("mixamorig_Head")
    var lfoot_idx = skel.find_bone("mixamorig_LeftFoot")
    var rfoot_idx = skel.find_bone("mixamorig_RightFoot")
    var hips_idx = skel.find_bone("mixamorig_Hips")
    print("head_rest:", skel.get_bone_global_rest(head_idx).origin)
    print("lfoot_rest:", skel.get_bone_global_rest(lfoot_idx).origin)
    print("rfoot_rest:", skel.get_bone_global_rest(rfoot_idx).origin)
    print("hips_rest:", skel.get_bone_global_rest(hips_idx).origin)
    # Also check mesh aabb
    for child in skel.get_children():
        if child is MeshInstance3D:
            print("mesh_aabb:", child.get_aabb())
    root.queue_free()
    quit()
