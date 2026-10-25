extends RefCounted


const CHANNELS: Dictionary = {"chunk_block": 4096, "chunk_water": 4096, "chunk_water_awake": 64, "chunk_fire": 4096}
const MAX_REGION_BYTES: int = 128 * 1024 * 1024
const MAX_PATCH_CHUNKS: int = 4096


static func valid_component(value: String) -> bool:
    if value.is_empty() or value.length() > 160:
        return false
    for character in value:
        if not "abcdefghijklmnopqrstuvwxyz0123456789_".contains(character):
            return false
    return true


static func region_coordinate(chunk: Vector3i) -> Vector3i:
    return Vector3i(floori(chunk.x / 256.0), floori(chunk.y / 256.0), floori(chunk.z / 256.0))


static func region_name(coordinate: Vector3i) -> String:
    return "c%d.%d.%d.txt" % [coordinate.x, coordinate.y, coordinate.z]


static func _coordinate_from_name(name_value: String) -> Variant:
    var parts: PackedStringArray = name_value.trim_prefix("c").trim_suffix(".txt").split(".")
    if parts.size() != 3:
        return null
    for part in parts:
        if not part.is_valid_int() or absi(part.to_int()) > 8388608:
            return null
    var coordinate := Vector3i(parts[0].to_int(), parts[1].to_int(), parts[2].to_int())
    return coordinate if region_name(coordinate) == name_value else null


static func _failure(message: String) -> Dictionary:
    return {"ok": false, "error": message}


static func _hash(bytes: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(bytes)
    return context.finish().hex_encode()


func _read_bytes(path: String) -> PackedByteArray:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null or file.get_length() > MAX_REGION_BYTES:
        return PackedByteArray()
    var bytes: PackedByteArray = file.get_buffer(file.get_length())
    file.close()
    return bytes


func _write_verified(path: String, bytes: PackedByteArray) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_buffer(bytes)
    file.flush()
    var error: Error = file.get_error()
    file.close()
    return error == OK and _hash(_read_bytes(path)) == _hash(bytes)


func _replace_file(path: String, bytes: PackedByteArray) -> bool:
    var pending: String = path + ".pending-" + Crypto.new().generate_random_bytes(8).hex_encode()
    if not _write_verified(pending, bytes):
        return false
    var error: Error = DirAccess.rename_absolute(pending, path)
    if error != OK:
        DirAccess.remove_absolute(pending)
    return error == OK


func _read_manifest(directory: String) -> Dictionary:
    var path: String = directory.path_join("manifest.json")
    if not FileAccess.file_exists(path):
        return {"ok": true, "regions": {}}
    var json := JSON.new()
    if json.parse(_read_bytes(path).get_string_from_utf8()) != OK or not json.data is Dictionary:
        return _failure("Unreadable region checkpoint manifest")
    var manifest: Dictionary = json.data
    if typeof(manifest.get("schema")) not in [TYPE_INT, TYPE_FLOAT] or manifest.get("schema") != 1 or not manifest.get("regions") is Dictionary:
        return _failure("Unsupported region checkpoint manifest")
    for name_value in manifest["regions"]:
        if not name_value is String or _coordinate_from_name(name_value) == null:
            return _failure("Invalid checkpoint region name")
        var entry = manifest["regions"][name_value]
        if not entry is Dictionary or not entry.get("generation") is String or not entry.get("sha256") is String:
            return _failure("Invalid checkpoint entry")
        if entry["generation"].length() != 32 or not entry["generation"].is_valid_hex_number() or entry["sha256"].length() != 64:
            return _failure("Invalid checkpoint digest or generation")
    return {"ok": true, "regions": manifest["regions"]}


func _validate_region(data: Dictionary, coordinate: Vector3i, block_ids: Dictionary) -> bool:
    if not data.get("coordinate") is Vector3i or data.get("coordinate") != coordinate:
        return false
    for channel in CHANNELS:
        if not data.get(channel) is Dictionary:
            return false
        for chunk in data[channel]:
            if not chunk is Vector3i or chunk.x % 16 != 0 or chunk.y % 16 != 0 or chunk.z % 16 != 0 or region_coordinate(chunk) != coordinate:
                return false
            var values = data[channel][chunk]
            if channel == "chunk_block":
                if not values is PackedInt32Array and not values is PackedByteArray:
                    return false
                for block_id in values:
                    if not block_ids.has(block_id):
                        return false
            elif not values is PackedByteArray:
                return false
            if values.size() != CHANNELS[channel]:
                return false
    return true


func _read_region(chunks_dir: String, region_namespace: String, coordinate: Vector3i, entries: Dictionary, block_ids: Dictionary) -> Dictionary:
    var name_value: String = region_name(coordinate)
    var path: String = chunks_dir.path_join(region_namespace).path_join(name_value)
    var expected_hash: String = ""
    if entries.has(name_value):
        var entry: Dictionary = entries[name_value]
        path = chunks_dir.path_join("coop").path_join(region_namespace).path_join(entry["generation"]).path_join(name_value)
        expected_hash = entry["sha256"]
    if not FileAccess.file_exists(path):
        if not expected_hash.is_empty():
            return _failure("Checkpoint payload is missing")
        return {"ok": true, "data": {"coordinate": coordinate, "save_version": "5.1.0", "chunk_block": {}, "chunk_water": {}, "chunk_water_awake": {}, "chunk_fire": {}}}
    var bytes: PackedByteArray = _read_bytes(path)
    if bytes.size() < 2 or bytes[0] != 31 or bytes[1] != 139 or (not expected_hash.is_empty() and _hash(bytes) != expected_hash):
        return _failure("Invalid region payload or checksum")
    var unpacked: PackedByteArray = bytes.decompress_dynamic(MAX_REGION_BYTES, FileAccess.COMPRESSION_GZIP)
    var json := JSON.new()
    if unpacked.is_empty() or json.parse(unpacked.get_string_from_utf8()) != OK:
        return _failure("Invalid region JSON")
    var decoded = JSON.to_native(json.data)
    if not decoded is Dictionary or not _validate_region(decoded, coordinate, block_ids):
        return _failure("Invalid region channels, coordinates or block IDs")
    return {"ok": true, "data": decoded}


func has_checkpoint(chunks_dir: String, region_namespace: String) -> bool:
    return valid_component(region_namespace) and FileAccess.file_exists(chunks_dir.path_join("coop").path_join(region_namespace).path_join("manifest.json"))


func read_regions(chunks_dir: String, region_namespace: String, block_ids: Dictionary) -> Dictionary:
    if not valid_component(region_namespace):
        return _failure("Invalid region region_namespace")
    var manifest: Dictionary = _read_manifest(chunks_dir.path_join("coop").path_join(region_namespace))
    if not manifest["ok"]:
        return manifest
    var names: Dictionary = {}
    if DirAccess.dir_exists_absolute(chunks_dir.path_join(region_namespace)):
        for name_value in DirAccess.get_files_at(chunks_dir.path_join(region_namespace)):
            if _coordinate_from_name(name_value) != null:
                names[name_value] = true
    for name_value in manifest["regions"]:
        names[name_value] = true
    var regions: Dictionary = {}
    for name_value in names:
        var coordinate: Vector3i = _coordinate_from_name(name_value)
        var region: Dictionary = _read_region(chunks_dir, region_namespace, coordinate, manifest["regions"], block_ids)
        if not region["ok"]:
            return region
        regions[coordinate] = region["data"]
    return {"ok": true, "regions": regions}


func commit_regions(chunks_dir: String, region_namespace: String, updates: Dictionary, block_ids: Dictionary) -> Dictionary:
    if not valid_component(region_namespace) or block_ids.is_empty():
        return _failure("Invalid checkpoint region_namespace or block table")
    var directory: String = chunks_dir.path_join("coop").path_join(region_namespace)
    var manifest: Dictionary = _read_manifest(directory)
    if not manifest["ok"]:
        return manifest
    var regions: Dictionary = {}
    for coordinate in updates:
        if not coordinate is Vector3i or not updates[coordinate] is Dictionary:
            return _failure("Invalid region update")
        var previous: Dictionary = _read_region(chunks_dir, region_namespace, coordinate, manifest["regions"], block_ids)
        if not previous["ok"]:
            return previous
        var merged: Dictionary = previous["data"].duplicate(true)
        for channel in updates[coordinate]:
            if not CHANNELS.has(channel) or not updates[coordinate][channel] is Dictionary:
                return _failure("Invalid update channel")
            for chunk in updates[coordinate][channel]:
                merged[channel][chunk] = updates[coordinate][channel][chunk]
        if not _validate_region(merged, coordinate, block_ids):
            return _failure("Invalid chunk update")
        regions[coordinate] = merged
    if regions.is_empty():
        return {"ok": true}
    var generation: String = Crypto.new().generate_random_bytes(16).hex_encode()
    var generation_dir: String = directory.path_join(generation)
    if DirAccess.make_dir_recursive_absolute(generation_dir) != OK:
        return _failure("Cannot create checkpoint directory")
    var entries: Dictionary = manifest["regions"].duplicate(true)
    for coordinate in regions:
        var name_value: String = region_name(coordinate)
        var bytes: PackedByteArray = JSON.stringify(JSON.from_native(regions[coordinate])).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
        if not _write_verified(generation_dir.path_join(name_value), bytes):
            return _failure("Cannot verify checkpoint payload")
        entries[name_value] = {"generation": generation, "sha256": _hash(bytes)}
    var manifest_path: String = directory.path_join("manifest.json")
    if FileAccess.file_exists(manifest_path) and not _replace_file(directory.path_join("previous.json"), _read_bytes(manifest_path)):
        return _failure("Cannot preserve previous checkpoint manifest")
    var bytes: PackedByteArray = JSON.stringify({"schema": 1, "regions": entries}).to_utf8_buffer()
    if not _replace_file(manifest_path, bytes):
        return _failure("Cannot publish checkpoint manifest")
    return {"ok": true, "generation": generation}


func commit_patch(chunks_dir: String, region_namespace: String, prefix: String, world_data: Dictionary, block_ids: Dictionary) -> Dictionary:
    if world_data.size() != 1 or not world_data.get(prefix + "world") is Dictionary:
        return _failure("Invalid patch region_namespace")
    var updates: Dictionary = {}
    var chunks: Dictionary = {}
    var root: Dictionary = world_data[prefix + "world"]
    if root.is_empty():
        return _failure("Empty patch channels")
    for field in root:
        var channel: String = str(field).trim_prefix(prefix)
        if field != prefix + channel or not CHANNELS.has(channel) or not root[field] is Dictionary:
            return _failure("Invalid patch channel")
        for chunk in root[field]:
            if not chunk is Vector3i:
                return _failure("Invalid patch coordinate")
            var coordinate: Vector3i = region_coordinate(chunk)
            if not updates.has(coordinate):
                updates[coordinate] = {}
            if not updates[coordinate].has(channel):
                updates[coordinate][channel] = {}
            updates[coordinate][channel][chunk] = root[field][chunk]
            chunks[chunk] = true
            if chunks.size() > MAX_PATCH_CHUNKS:
                return _failure("Patch exceeds checkpoint limit")
    return commit_regions(chunks_dir, region_namespace, updates, block_ids)

# Existing checkpoints take precedence; legacy input is retained as a recovery source.
func migrate_legacy(chunks_dir: String, region_namespace: String, plain_namespace: String, save_data: Dictionary, block_ids: Dictionary, allow_plain_owner: bool = false) -> Dictionary:
    if not valid_component(region_namespace) or not valid_component(plain_namespace):
        return _failure("Invalid migration namespace")
    var existing: Dictionary = read_regions(chunks_dir, region_namespace, block_ids)
    if not existing["ok"] or has_checkpoint(chunks_dir, region_namespace):
        return existing
    var source_prefix: String = region_namespace + "_"
    if not save_data.has(source_prefix + "world"):
        if region_namespace != plain_namespace and not allow_plain_owner:
            return {"ok": true}
        source_prefix = plain_namespace + "_"
    if not save_data.has(source_prefix + "world"):
        return {"ok": true}
    var source = save_data[source_prefix + "world"]
    if not source is Dictionary or source.size() != CHANNELS.size():
        return _failure("Invalid legacy world channels")
    var prefix: String = region_namespace + "_"
    var converted: Dictionary = {}
    var validation: Dictionary = {}
    var count: Dictionary = {}
    for channel in CHANNELS:
        var values = source.get(source_prefix + channel)
        if not values is Dictionary:
            return _failure("Invalid legacy channel")
        converted[prefix + channel] = {}
        for chunk in values:
            if not chunk is Vector3i:
                return _failure("Invalid legacy coordinate")
            var coordinate: Vector3i = region_coordinate(chunk)
            if not validation.has(coordinate):
                validation[coordinate] = {"coordinate": coordinate}
                for entry in CHANNELS:
                    validation[coordinate][entry] = {}
            validation[coordinate][channel][chunk] = values[chunk]
            count[chunk] = true
            if count.size() > MAX_PATCH_CHUNKS:
                return _failure("Legacy migration exceeds checkpoint limit")
            if not existing["regions"].get(coordinate, {}).get(channel, {}).has(chunk):
                converted[prefix + channel][chunk] = values[chunk]
    for coordinate in validation:
        if not _validate_region(validation[coordinate], coordinate, block_ids):
            return _failure("Invalid legacy region payload")
    var committed: Dictionary = commit_patch(chunks_dir, region_namespace, prefix, {prefix + "world": converted}, block_ids)
    if not committed["ok"]:
        return committed
    return read_regions(chunks_dir, region_namespace, block_ids)
