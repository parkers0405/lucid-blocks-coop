@tool
extends SceneTree

func _init() -> void:
    var scene = load("res://coop_mod/animation_workflow/source_fbx/mr_frog_base/mr_frog_tpose.fbx")
    if not (scene is PackedScene):
        print("FAILED to load mr_frog")
        quit(1)
        return
    var root = (scene as PackedScene).instantiate()
    _dump(root, "")
    root.queue_free()
    quit()

func _dump(node: Node, indent: String) -> void:
    var extra = ""
    if node is MeshInstance3D:
        var mi = node as MeshInstance3D
        extra = " [MESH verts=%s vis=%s surfaces=%d]" % [str(mi.mesh.get_faces().size()/3) if mi.mesh else "null", mi.visible, mi.mesh.get_surface_count() if mi.mesh else 0]
    elif node is Skeleton3D:
        extra = " [SKEL bones=%d]" % (node as Skeleton3D).get_bone_count()
    print("%s%s (%s)%s" % [indent, node.name, node.get_class(), extra])
    for child in node.get_children():
        _dump(child, indent + "  ")
