@tool
extends SceneTree

func _init() -> void:
    var AvatarRegistry = load("res://coop_mod/avatar_registry.gd")
    var entries = AvatarRegistry.list_avatar_entries()
    print("total_entries=", entries.size())
    for e in entries:
        print("  id=", e.get("id"), " name=", e.get("name"), " path=", e.get("path"))
    
    var frog = AvatarRegistry.get_avatar_entry("mr_frog")
    print("mr_frog entry=", frog.get("id"), " path=", frog.get("path"))
    print("mr_frog exists=", ResourceLoader.exists(str(frog.get("path", ""))))
    
    var itachi = AvatarRegistry.get_avatar_entry("itachi")
    print("itachi entry=", itachi.get("id"), " path=", itachi.get("path"))
    print("itachi exists=", ResourceLoader.exists(str(itachi.get("path", ""))))
    quit()
