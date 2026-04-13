@tool
extends SceneTree


func _init() -> void:
    var scene = load("res://coop_mod/animation_workflow/source_fbx/core/walk.fbx")
    var inst = (scene as PackedScene).instantiate()
    var ap: AnimationPlayer = null
    for child in inst.get_children():
        if child is AnimationPlayer:
            ap = child as AnimationPlayer
            break
    if ap == null:
        print("no AP")
        inst.queue_free()
        quit()
        return
    var anim = ap.get_animation("mixamo_com")
    print("total_tracks", anim.get_track_count())
    for i in range(anim.get_track_count()):
        var p = str(anim.track_get_path(i))
        print("track[%d] type=%d path=%s" % [i, anim.track_get_type(i), p])
    inst.queue_free()
    quit()
