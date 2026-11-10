extends SceneTree

func _initialize() -> void:
    var probe = load("res://diagnostic.gd").new()
    root.add_child(probe)
    # Startup snapshots can see detached scripted nodes before node_added sees them.
    var detached = load("res://diagnostic.gd").new()
    detached.name = "DetachedFixture"
    probe._observe(detached)
    probe._observe(detached)
    assert(detached.ready.get_connections().size() == 1)
    detached.free()
