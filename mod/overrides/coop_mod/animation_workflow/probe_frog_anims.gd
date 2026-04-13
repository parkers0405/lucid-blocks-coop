@tool
extends SceneTree

func _init() -> void:
    var scene = load("res://coop_mod/animation_workflow/source_fbx/mr_frog_anims/breathing_idle.fbx")
    if not (scene is PackedScene):
        print("FAILED")
        quit(1)
        return
    var root = (scene as PackedScene).instantiate()
    var ap: AnimationPlayer = null
    for child in root.get_children():
        if child is AnimationPlayer:
            ap = child as AnimationPlayer
            break
    if ap == null:
        print("NO AP")
        quit(1)
        return
    var anim = ap.get_animation("mixamo_com")
    if anim == null:
        print("NO mixamo_com, available:", ap.get_animation_list())
        quit(1)
        return
    for i in range(min(anim.get_track_count(), 10)):
        print("track", i, "path=", anim.track_get_path(i))
    root.queue_free()
    quit()
