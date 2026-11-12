extends RefCounted

static func valid_bundle(bundle: Variant, dimension: String, allowed_scenes: Dictionary) -> bool:
    if not bundle is Dictionary or not bundle.get("uuid") is String:
        return false
    if not bundle.get("position") is Vector3 or not bundle["position"].is_finite():
        return false
    if not bundle.get("save_data") is Dictionary:
        return false
    var uuid: String = bundle["uuid"]
    if uuid.length() != 36 or not uuid.replace("-", "").is_valid_hex_number() or not allowed_scenes.has(bundle.get("scene_path")):
        return false
    var data: Dictionary = bundle["save_data"]
    if data.size() != 1 or not data.get(dimension) is Dictionary:
        return false
    var root: Dictionary = data[dimension]
    if root.size() != 1 or not root.get("node") is Dictionary:
        return false
    var nodes: Dictionary = root["node"]
    return nodes.size() == 1 and nodes.get(uuid) is Dictionary
