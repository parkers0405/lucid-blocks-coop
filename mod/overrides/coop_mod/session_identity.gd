extends RefCounted

const Files = preload("res://coop_mod/region_checkpoint.gd")
var files := Files.new()

func read_record(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var bytes: PackedByteArray = files._read_bytes(path)
    if bytes.is_empty() or bytes.size() > 1048576:
        return {"invalid": true}
    var value = JSON.parse_string(bytes.get_string_from_utf8())
    if not value is Dictionary:
        return {"invalid": true}
    return value

func write_record(path: String, value: Dictionary) -> bool:
    if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
        return false
    return files._replace_file(path, JSON.stringify(value).to_utf8_buffer())

static func random_id() -> String:
    return Crypto.new().generate_random_bytes(32).hex_encode()

static func valid_token(value: Variant) -> bool:
    return value is String and value.length() == 64 and value.is_valid_hex_number()

static func valid_lan_key(value: Variant) -> bool:
    return value is String and value.begins_with("lan_") and valid_token(value.trim_prefix("lan_"))

func admit(path: String, token: String, steam_id: int, occupied: Array) -> Dictionary:
    var record: Dictionary = read_record(path)
    if record.has("invalid"):
        return {}
    var identities = record.get("identities", {})
    if not identities is Dictionary:
        return {}
    var player_key: String = ""
    var issued_token: String = ""
    if steam_id > 0:
        player_key = "steam_%d" % steam_id
    elif not token.is_empty():
        if not valid_token(token):
            return {}
        var saved_key = identities.get(token.sha256_text())
        if not valid_lan_key(saved_key):
            return {}
        player_key = saved_key
    else:
        issued_token = random_id()
        player_key = "lan_" + random_id()
        identities[issued_token.sha256_text()] = player_key
    if occupied.has(player_key) or not Files.valid_component(player_key):
        return {}
    # A new LAN identity must survive a restart before it can join.
    if not issued_token.is_empty() and not write_record(path, {"identities": identities}):
        return {}
    return {"key": player_key, "token": issued_token}
