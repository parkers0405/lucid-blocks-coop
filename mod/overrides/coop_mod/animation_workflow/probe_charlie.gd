@tool
extends SceneTree
func _init() -> void:
    var scene = load("res://coop_mod/animation_workflow/source_fbx/charlie_base/charlie_tpose.fbx")
    var root = (scene as PackedScene).instantiate()
    var meshes = []
    _find_meshes(root, meshes)
    for m in meshes:
        print("mesh:", m.name, "aabb:", m.get_aabb())
    var bounds = AABB()
    var first = true
    for m in meshes:
        if first:
            bounds = m.get_aabb()
            first = false
        else:
            bounds = bounds.merge(m.get_aabb())
    print("combined_bounds pos:", bounds.position, "size:", bounds.size)
    print("height:", bounds.size.y, "bottom_y:", bounds.position.y)
    # What scale and offset would we get?
    var target_h = 1.55
    var scale_f = target_h / bounds.size.y
    var ground_offset = 0.15
    var pos_y = -bounds.position.y * scale_f + ground_offset
    print("scale:", scale_f, "pos_y:", pos_y)
    print("feet_world_y:", bounds.position.y * scale_f + pos_y)
    print("head_world_y:", (bounds.position.y + bounds.size.y) * scale_f + pos_y)
    root.queue_free()
    quit()

func _find_meshes(node, arr):
    if node is MeshInstance3D:
        arr.append(node)
    for c in node.get_children():
        _find_meshes(c, arr)
