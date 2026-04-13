@tool
extends SceneTree


const AVATAR_ASSETS_DIR: String = "res://coop_mod/avatar_assets"
const DEFAULT_MODEL_PATH: String = "res://coop_mod/animation_workflow/source_fbx/default_base/low_poly_character.fbx"

# Bone name mapping: default canonical name -> list of aliases to search on source skeleton
const BONE_MAP: Dictionary = {
    "mixamorig_Hips": ["hips", "Hips", "mixamorig:Hips", "mixamorig1_Hips"],
    "mixamorig_Spine": ["spine", "Spine", "mixamorig:Spine", "mixamorig1_Spine"],
    "mixamorig_Spine1": ["spine1", "Spine1", "mixamorig:Spine1", "mixamorig1_Spine1", "Chest_00"],
    "mixamorig_Spine2": ["chest", "Spine2", "mixamorig:Spine2", "mixamorig1_Spine2", "Chest"],
    "mixamorig_Neck": ["neck", "Neck", "mixamorig:Neck", "mixamorig1_Neck"],
    "mixamorig_Head": ["head", "Head", "mixamorig:Head", "mixamorig1_Head"],
    "mixamorig_LeftShoulder": ["shoulder.L", "LeftShoulder"],
    "mixamorig_LeftArm": ["upperarm.L", "LeftArm", "UpperArm.L"],
    "mixamorig_LeftForeArm": ["lowerarm.L", "LeftForeArm", "LowerArm.L"],
    "mixamorig_LeftHand": ["hand.L", "LeftHand", "Hand.L"],
    "mixamorig_RightShoulder": ["shoulder.R", "RightShoulder"],
    "mixamorig_RightArm": ["upperarm.R", "RightArm", "UpperArm.R"],
    "mixamorig_RightForeArm": ["lowerarm.R", "RightForeArm", "LowerArm.R"],
    "mixamorig_RightHand": ["hand.R", "RightHand", "Hand.R"],
    "mixamorig_LeftUpLeg": ["upperleg.L", "LeftUpLeg", "UpperLeg.L"],
    "mixamorig_LeftLeg": ["lowerleg.L", "LeftLeg", "LowerLeg.L"],
    "mixamorig_LeftFoot": ["foot.L", "LeftFoot", "Foot.L"],
    "mixamorig_LeftToeBase": ["toe.L", "LeftToeBase", "ToeBase.L"],
    "mixamorig_RightUpLeg": ["upperleg.R", "RightUpLeg", "UpperLeg.R"],
    "mixamorig_RightLeg": ["lowerleg.R", "RightLeg", "LowerLeg.R"],
    "mixamorig_RightFoot": ["foot.R", "RightFoot", "Foot.R"],
    "mixamorig_RightToeBase": ["toe.R", "RightToeBase", "ToeBase.R"],
}


func _init() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty():
        push_error("avatar_normalizer: expected avatar id argument")
        quit(1)
        return

    var avatar_id: String = args[0].strip_edges().to_lower()
    var ok: bool = _normalize_avatar(avatar_id)
    quit(0 if ok else 1)


func _normalize_avatar(avatar_id: String) -> bool:
    var manifest_path: String = "%s/%s/avatar.json" % [AVATAR_ASSETS_DIR, avatar_id]
    var manifest: Dictionary = _load_manifest(manifest_path)
    if manifest.is_empty():
        push_error("avatar_normalizer: failed to load manifest %s" % manifest_path)
        return false

    var source_model_path: String = str(manifest.get("source_model", manifest.get("model", ""))).strip_edges()
    if source_model_path == "":
        push_error("avatar_normalizer: manifest has no source model")
        return false

    # Load default reference skeleton
    var default_scene := load(DEFAULT_MODEL_PATH) as PackedScene
    if default_scene == null:
        push_error("avatar_normalizer: failed to load default model")
        return false
    var default_root := default_scene.instantiate()
    var default_skeleton: Skeleton3D = _find_first_skeleton(default_root)
    if default_skeleton == null:
        push_error("avatar_normalizer: no skeleton in default model")
        default_root.queue_free()
        return false

    # Load source avatar
    var source_scene = load(source_model_path)
    if not (source_scene is PackedScene):
        push_error("avatar_normalizer: source model is not a PackedScene %s" % source_model_path)
        default_root.queue_free()
        return false

    var source_root: Node = (source_scene as PackedScene).instantiate()
    if source_root == null or not (source_root is Node3D):
        push_error("avatar_normalizer: source scene did not instantiate as Node3D")
        default_root.queue_free()
        return false

    source_root.name = "%s_normalized" % avatar_id

    var source_skeleton: Skeleton3D = _find_first_skeleton(source_root)
    if source_skeleton == null:
        push_error("avatar_normalizer: no Skeleton3D found in %s" % source_model_path)
        source_root.queue_free()
        default_root.queue_free()
        return false

    # Build bone name mapping from manifest overrides + alias table
    var bone_name_map: Dictionary = _build_bone_name_map(source_skeleton, manifest)

    # Rename source bones to match default canonical names
    var renamed_bones: Dictionary = _rename_bones(source_skeleton, bone_name_map)

    # Bake rest-pose correction: make source rest poses match default rest poses
    _bake_rest_pose_correction(source_skeleton, default_skeleton, bone_name_map)

    # Fix skin bindings to match renamed bones
    _normalize_skin_bindings(source_root, source_skeleton, renamed_bones)

    # Strip imported AnimationPlayer/AnimationTree that would fight runtime clips
    _strip_animation_nodes(source_root)

    # Force visible materials
    _normalize_materials(source_root, manifest)

    # Force all geometry visible
    _force_visible(source_root)

    # Save
    var output_path: String = "%s/%s/%s_normalized.tscn" % [AVATAR_ASSETS_DIR, avatar_id, avatar_id]
    var output_abs_dir: String = ProjectSettings.globalize_path(output_path.get_base_dir())
    DirAccess.make_dir_recursive_absolute(output_abs_dir)

    var packed_scene := PackedScene.new()
    var pack_result: int = packed_scene.pack(source_root)
    if pack_result != OK:
        push_error("avatar_normalizer: failed to pack normalized scene %s" % output_path)
        source_root.queue_free()
        default_root.queue_free()
        return false

    var save_result: int = ResourceSaver.save(packed_scene, output_path)
    source_root.queue_free()
    default_root.queue_free()
    if save_result != OK:
        push_error("avatar_normalizer: failed to save %s" % output_path)
        return false

    print("avatar_normalizer: wrote %s" % output_path)
    return true


func _load_manifest(manifest_path: String) -> Dictionary:
    if not FileAccess.file_exists(manifest_path):
        return {}
    var file := FileAccess.open(manifest_path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}


func _find_first_skeleton(root: Node) -> Skeleton3D:
    if root is Skeleton3D:
        return root as Skeleton3D
    for child in root.get_children():
        var found: Skeleton3D = _find_first_skeleton(child)
        if found != null:
            return found
    return null


func _build_bone_name_map(source_skeleton: Skeleton3D, manifest: Dictionary) -> Dictionary:
    # Returns: { canonical_name: source_bone_name }
    var result: Dictionary = {}

    # First check manifest bone_overrides (canonical -> source)
    var overrides: Variant = manifest.get("bone_overrides", {})
    if overrides is Dictionary:
        for canonical_name_variant in overrides.keys():
            var canonical_name: String = str(canonical_name_variant)
            var source_name: String = str((overrides as Dictionary).get(canonical_name_variant, ""))
            if source_name != "" and source_skeleton.find_bone(source_name) != -1:
                result[canonical_name] = source_name

    # Then fill in from BONE_MAP aliases
    for canonical_name in BONE_MAP.keys():
        if result.has(canonical_name):
            continue
        # Check if canonical name itself exists on source
        if source_skeleton.find_bone(canonical_name) != -1:
            result[canonical_name] = canonical_name
            continue
        # Search aliases
        var aliases: Array = BONE_MAP[canonical_name]
        for alias in aliases:
            if source_skeleton.find_bone(str(alias)) != -1:
                result[canonical_name] = str(alias)
                break

    return result


func _rename_bones(source_skeleton: Skeleton3D, bone_name_map: Dictionary) -> Dictionary:
    # Returns: { old_name: new_name }
    var renamed: Dictionary = {}
    for canonical_name in bone_name_map.keys():
        var source_name: String = bone_name_map[canonical_name]
        if source_name == canonical_name:
            continue
        var bone_index: int = source_skeleton.find_bone(source_name)
        if bone_index == -1:
            continue
        source_skeleton.set_bone_name(bone_index, canonical_name)
        renamed[source_name] = canonical_name
        print("avatar_normalizer: renamed bone '%s' -> '%s'" % [source_name, canonical_name])
    return renamed


func _bake_rest_pose_correction(_source_skeleton: Skeleton3D, _default_skeleton: Skeleton3D, _bone_name_map: Dictionary) -> void:
    # INTENTIONALLY EMPTY: Do NOT modify rest poses.
    # Changing rest poses breaks mesh deformation because skin weights are bound
    # to the original rest poses. Instead, animation tracks are pre-corrected at
    # runtime clip build time in RemotePlayerMarker._correct_animation_for_rest_pose().
    pass


func _normalize_skin_bindings(root: Node, skeleton: Skeleton3D, renamed_bones: Dictionary) -> void:
    if root is MeshInstance3D:
        var mesh_node := root as MeshInstance3D
        if mesh_node.skin != null:
            var normalized_skin: Skin = mesh_node.skin.duplicate(true)
            for bind_index in range(normalized_skin.get_bind_count()):
                var bind_name: String = str(normalized_skin.get_bind_name(bind_index))
                var canonical_name: String = str(renamed_bones.get(bind_name, bind_name))
                var bone_index: int = skeleton.find_bone(canonical_name)
                if canonical_name != "":
                    normalized_skin.set_bind_name(bind_index, StringName(canonical_name))
                if bone_index != -1:
                    normalized_skin.set_bind_bone(bind_index, bone_index)
            mesh_node.skin = normalized_skin

    for child in root.get_children():
        _normalize_skin_bindings(child, skeleton, renamed_bones)


func _strip_animation_nodes(root: Node) -> void:
    for child in root.get_children():
        _strip_animation_nodes(child)

    if root is AnimationPlayer or root is AnimationTree:
        var parent: Node = root.get_parent()
        if parent != null:
            parent.remove_child(root)
        root.queue_free()


func _normalize_materials(root: Node, manifest: Dictionary) -> void:
    var texture_override_path: String = str(manifest.get("texture_override", "")).strip_edges()
    var texture_override: Texture2D = load(texture_override_path) as Texture2D if texture_override_path != "" else null
    _normalize_materials_recursive(root, texture_override)


func _normalize_materials_recursive(root: Node, texture_override: Texture2D) -> void:
    if root is MeshInstance3D:
        var mesh_node := root as MeshInstance3D
        mesh_node.visible = true
        if mesh_node.mesh != null:
            for surface_index in range(mesh_node.mesh.get_surface_count()):
                if texture_override != null:
                    mesh_node.set_surface_override_material(surface_index, _make_texture_material(texture_override))
                else:
                    var source_material: Material = mesh_node.get_active_material(surface_index)
                    if source_material is BaseMaterial3D:
                        var dup := (source_material as BaseMaterial3D).duplicate() as BaseMaterial3D
                        dup.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
                        dup.cull_mode = BaseMaterial3D.CULL_DISABLED
                        dup.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
                        mesh_node.set_surface_override_material(surface_index, dup)
                    else:
                        var fallback := StandardMaterial3D.new()
                        fallback.albedo_color = Color.WHITE
                        fallback.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
                        fallback.cull_mode = BaseMaterial3D.CULL_DISABLED
                        fallback.roughness = 1.0
                        mesh_node.set_surface_override_material(surface_index, fallback)

    for child in root.get_children():
        _normalize_materials_recursive(child, texture_override)


func _make_texture_material(texture: Texture2D) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_texture = texture
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
    material.roughness = 1.0
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material


func _force_visible(root: Node) -> void:
    if root is GeometryInstance3D:
        var geometry := root as GeometryInstance3D
        geometry.visible = true
        geometry.extra_cull_margin = 12.0
        geometry.ignore_occlusion_culling = true
    for child in root.get_children():
        _force_visible(child)
