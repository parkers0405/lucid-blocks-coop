extends RefCounted

const DEFAULT_AVATAR_ID: String = "default_blocky"
const AVATAR_ASSETS_DIR: String = "res://coop_mod/avatar_assets"

static var _cache_loaded: bool = false
static var _cache: Dictionary = {}
static var _ordered_ids: Array = []


static func invalidate_cache() -> void:
    _cache_loaded = false
    _cache.clear()
    _ordered_ids.clear()


static func list_avatar_entries() -> Array:
    _ensure_cache()
    var entries: Array = []
    for avatar_id in _ordered_ids:
        if _cache.has(avatar_id):
            entries.append((_cache[avatar_id] as Dictionary).duplicate(true))
    return entries


static func get_avatar_entry(raw_avatar_id: String) -> Dictionary:
    _ensure_cache()
    var avatar_id: String = _normalize_avatar_id(raw_avatar_id)
    if _cache.has(avatar_id):
        return (_cache[avatar_id] as Dictionary).duplicate(true)
    return (_cache.get(DEFAULT_AVATAR_ID, _default_entry()) as Dictionary).duplicate(true)


static func _ensure_cache() -> void:
    if _cache_loaded:
        return

    _cache_loaded = true
    _cache.clear()
    _ordered_ids.clear()

    var default_entry: Dictionary = _default_entry()
    _cache[DEFAULT_AVATAR_ID] = default_entry
    _ordered_ids.append(DEFAULT_AVATAR_ID)

    var avatar_dir := DirAccess.open(AVATAR_ASSETS_DIR)
    if avatar_dir == null:
        return

    var folder_names: Array = []
    avatar_dir.list_dir_begin()
    var entry_name: String = avatar_dir.get_next()
    while entry_name != "":
        if avatar_dir.current_is_dir() and not entry_name.begins_with(".") and entry_name != "shared":
            folder_names.append(entry_name)
        entry_name = avatar_dir.get_next()
    avatar_dir.list_dir_end()
    folder_names.sort()

    for folder_name_variant in folder_names:
        var folder_name: String = str(folder_name_variant)
        var loaded_entry: Dictionary = _load_avatar_dir(folder_name)
        if loaded_entry.is_empty():
            continue
        var avatar_id: String = _normalize_avatar_id(str(loaded_entry.get("id", folder_name)))
        loaded_entry["id"] = avatar_id
        _cache[avatar_id] = _merge_entry_defaults(loaded_entry)
        if avatar_id != DEFAULT_AVATAR_ID:
            _ordered_ids.append(avatar_id)


static func _load_avatar_dir(folder_name: String) -> Dictionary:
    var folder_path: String = AVATAR_ASSETS_DIR + "/" + folder_name
    var manifest_path: String = folder_path + "/avatar.json"
    var manifest: Dictionary = {}
    if FileAccess.file_exists(manifest_path):
        var file := FileAccess.open(manifest_path, FileAccess.READ)
        if file != null:
            var parsed = JSON.parse_string(file.get_as_text())
            if parsed is Dictionary:
                manifest = parsed

    var model_field: String = str(manifest.get("model", "")).strip_edges()
    var model_path: String = ""
    if model_field != "":
        model_path = model_field if model_field.begins_with("res://") else folder_path + "/" + model_field
    else:
        for candidate_variant in [
            folder_path + "/model.glb",
            folder_path + "/character.glb",
            folder_path + "/" + folder_name + ".glb",
            folder_path + "/low_poly_character.glb",
            folder_path + "/mr_frog.glb",
            folder_path + "/pim.glb",
        ]:
            var candidate: String = str(candidate_variant)
            if ResourceLoader.exists(candidate):
                model_path = candidate
                break

    if model_path == "" or not ResourceLoader.exists(model_path):
        return {}

    manifest["folder"] = folder_name
    manifest["path"] = model_path
    if not manifest.has("name"):
        manifest["name"] = folder_name.replace("_", " ").capitalize()
    if not manifest.has("id"):
        manifest["id"] = folder_name
    return manifest


static func _merge_entry_defaults(entry: Dictionary) -> Dictionary:
    var merged: Dictionary = {
        "id": "",
        "name": "Unnamed",
        "folder": "",
        "path": "",
        "height": 2.05,
        "ground_offset": -0.01,
        "preview_height": 1.8,
        "preview_yaw": 160.0,
        "animation_mode": "procedural",
        "skin_mode": "passthrough",
        "look_sign": -1.0,
        "neutral_bias_deg": 0.0,
        "head_scale": 0.6,
        "neck_scale": 0.4,
        "show_held_items": false,
        "default_skin_color": [0.87, 0.75, 0.65],
        "locomotion_arm_offset_x": 0.0,
        "locomotion_arm_offset_y": 0.0,
        "locomotion_arm_offset_z": 0.0,
        "locomotion_forearm_offset_x": 0.0,
        "locomotion_forearm_offset_z": 0.0,
        "locomotion_leg_scale": 1.0,
        "locomotion_leg_yaw": 0.0,
        "locomotion_foot_yaw": 0.0,
        "bone_overrides": {},
    }
    for key in entry.keys():
        merged[key] = entry[key]
    return merged


static func _default_entry() -> Dictionary:
    return _merge_entry_defaults({
        "id": DEFAULT_AVATAR_ID,
        "name": "Default",
        "folder": "rigged_default",
        "path": "res://coop_mod/avatar_assets/rigged_default/low_poly_character.glb",
        "height": 2.05,
        "ground_offset": -0.01,
        "preview_height": 1.8,
        "preview_yaw": 160.0,
        "animation_mode": "mixamo_fbx_runtime",
        "skin_mode": "default_shader",
        "look_sign": -1.0,
        "neutral_bias_deg": 8.0,
        "head_scale": 0.85,
        "neck_scale": 0.6,
        "show_held_items": false,
        "default_skin_color": [0.87, 0.75, 0.65],
        "locomotion_arm_offset_x": 0.0,
        "locomotion_arm_offset_y": 0.0,
        "locomotion_arm_offset_z": 0.0,
        "locomotion_forearm_offset_x": 0.0,
        "locomotion_forearm_offset_z": 0.0,
        "locomotion_leg_scale": 1.0,
        "locomotion_leg_yaw": 0.0,
        "locomotion_foot_yaw": 0.0,
        "bone_overrides": {},
    })


static func _normalize_avatar_id(raw_avatar_id: String) -> String:
    var normalized: String = raw_avatar_id.strip_edges().to_lower()
    return normalized if normalized != "" else DEFAULT_AVATAR_ID
