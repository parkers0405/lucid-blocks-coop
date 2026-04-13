@tool
extends SceneTree

const BONE_MAP_PATH := "res://addons/mixamo_animation_retargeter/mixamo_bone_map.tres"
const GENERATED_DIR := "res://coop_mod/animation_workflow/generated/mixamo_runtime"

const MODEL_CONFIGS := [
	{
		"path": "res://coop_mod/animation_workflow/source_fbx/default_base/low_poly_character.fbx",
		"skeleton_path": "PATH:Skeleton",
	},
	{
		"path": "res://coop_mod/animation_workflow/source_fbx/pim_base/pim_mixamo_tpose.fbx",
		"skeleton_path": "PATH:Armature/Skeleton",
	},
]

const ANIMATION_CONFIGS := [
	{
		"source": "res://coop_mod/animation_workflow/source_fbx/core/breathing_idle.fbx",
		"target": GENERATED_DIR + "/breathing_idle.res",
	},
	{
		"source": "res://coop_mod/animation_workflow/source_fbx/core/idle.fbx",
		"target": GENERATED_DIR + "/idle.res",
	},
	{
		"source": "res://coop_mod/animation_workflow/source_fbx/core/walk.fbx",
		"target": GENERATED_DIR + "/walk.res",
	},
	{
		"source": "res://coop_mod/animation_workflow/source_fbx/core/run.fbx",
		"target": GENERATED_DIR + "/run.res",
	},
	{
		"source": "res://coop_mod/animation_workflow/source_fbx/core/jump_run.fbx",
		"target": GENERATED_DIR + "/jump_run.res",
	},
	{
		"source": "res://coop_mod/animation_workflow/source_fbx/core/crouch_idle.fbx",
		"target": GENERATED_DIR + "/crouch_idle.res",
	},
	{
		"source": "res://coop_mod/animation_workflow/source_fbx/core/crouch_walk.fbx",
		"target": GENERATED_DIR + "/crouch_walk.res",
	},
	{
		"source": "res://coop_mod/animation_workflow/source_fbx/core/hit_react.fbx",
		"target": GENERATED_DIR + "/hit_react.res",
	},
	{
		"source": "res://coop_mod/animation_workflow/source_fbx/core/turn_left.fbx",
		"target": GENERATED_DIR + "/turn_left.res",
	},
	{
		"source": "res://coop_mod/animation_workflow/source_fbx/core/turn_right.fbx",
		"target": GENERATED_DIR + "/turn_right.res",
	},
	{
		"source": "res://coop_mod/animation_workflow/source_fbx/core/death.fbx",
		"target": GENERATED_DIR + "/death.res",
	},
	{
		"source": "res://coop_mod/animation_workflow/source_fbx/core/attack.fbx",
		"target": GENERATED_DIR + "/attack.res",
	},
	{
		"source": "res://coop_mod/animation_workflow/source_fbx/core/punch_combo.fbx",
		"target": GENERATED_DIR + "/punch_combo.res",
	},
	{
		"source": "res://coop_mod/animation_workflow/source_fbx/core/standing_melee_attack_horizontal.fbx",
		"target": GENERATED_DIR + "/melee_attack.res",
	},
]


func _init() -> void:
	var dir_error := DirAccess.make_dir_recursive_absolute(GENERATED_DIR)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		push_error("configure_mixamo_pipeline: failed to create generated dir")
		quit(1)
		return

	for model_config in MODEL_CONFIGS:
		_configure_model_import(str(model_config.path), str(model_config.skeleton_path))

	for animation_config in ANIMATION_CONFIGS:
		_configure_animation_import(str(animation_config.source), str(animation_config.target))

	quit()


func _configure_model_import(resource_path: String, skeleton_path: String) -> void:
	var import_path := resource_path + ".import"
	var config := ConfigFile.new()
	if config.load(import_path) != OK:
		push_warning("configure_mixamo_pipeline: failed to load %s" % import_path)
		return

	var subresources: Dictionary = config.get_value("params", "_subresources", {})
	var nodes: Dictionary = subresources.get("nodes", {})
	var skeleton_settings: Dictionary = nodes.get(skeleton_path, {})
	skeleton_settings["retarget/bone_map"] = load(BONE_MAP_PATH)
	skeleton_settings["retarget/bone_renamer/rename_bones"] = true
	skeleton_settings["retarget/bone_renamer/unique_node/skeleton_name"] = "Skeleton"
	skeleton_settings["retarget/rest_fixer/overwrite_axis"] = true
	skeleton_settings["retarget/rest_fixer/fix_silhouette/enable"] = true
	skeleton_settings["retarget/rest_fixer/apply_node_transform"] = true
	skeleton_settings["retarget/remove_tracks/unmapped_bones"] = true
	nodes[skeleton_path] = skeleton_settings
	subresources["nodes"] = nodes
	config.set_value("params", "_subresources", subresources)
	config.save(import_path)
	print("configure_mixamo_pipeline: configured model ", resource_path)


func _configure_animation_import(resource_path: String, save_path: String) -> void:
	var import_path := resource_path + ".import"
	var config := ConfigFile.new()
	if config.load(import_path) != OK:
		push_warning("configure_mixamo_pipeline: failed to load %s" % import_path)
		return

	var subresources: Dictionary = config.get_value("params", "_subresources", {})
	var nodes: Dictionary = subresources.get("nodes", {})
	var skeleton_settings: Dictionary = nodes.get("PATH:Skeleton3D", {})
	skeleton_settings["retarget/bone_map"] = load(BONE_MAP_PATH)
	skeleton_settings["retarget/bone_renamer/unique_node/skeleton_name"] = "Skeleton"
	skeleton_settings["retarget/remove_tracks/unmapped_bones"] = true
	nodes["PATH:Skeleton3D"] = skeleton_settings
	subresources["nodes"] = nodes

	var animations: Dictionary = subresources.get("animations", {})
	var mixamo_settings: Dictionary = animations.get("mixamo_com", {})
	mixamo_settings["save_to_file/enabled"] = true
	mixamo_settings["save_to_file/keep_custom_tracks"] = ""
	mixamo_settings["save_to_file/path"] = save_path
	mixamo_settings["settings/loop_mode"] = 0
	animations["mixamo_com"] = mixamo_settings
	subresources["animations"] = animations

	config.set_value("params", "_subresources", subresources)
	config.save(import_path)
	print("configure_mixamo_pipeline: configured animation ", resource_path, " -> ", save_path)
