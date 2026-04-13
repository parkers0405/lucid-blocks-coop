@tool
extends SceneTree


func _init() -> void:
	var anim := load("res://coop_mod/animation_workflow/generated/mixamo_runtime/walk.res") as Animation
	if anim == null:
		print("no anim")
		quit(1)
		return
	print("tracks", anim.get_track_count())
	for i in range(min(anim.get_track_count(), 20)):
		print(i, "type=", anim.track_get_type(i), "path=", anim.track_get_path(i))
	quit()
