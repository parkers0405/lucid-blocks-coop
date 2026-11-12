extends RefCounted

const RADIUS: float = 144.0
const HOST_RADIUS: float = 128.0
const MAX_CHUNKS: int = 16
var revisions: Dictionary = {}
var fingerprints: Dictionary = {}
var lease_epoch: int = 0
var lease_owners: Dictionary = {}
var lease_objects: Dictionary = {}

func leased_owner(chunk: Vector3i, instance: String) -> int:
    return int(lease_owners.get(chunk_key(instance, chunk), 1))

func install_lease(epoch: int, chunks: Dictionary, objects: Dictionary) -> bool:
    if epoch <= lease_epoch or chunks.size() > 32768 or objects.size() > 8192:
        return false
    for key in chunks:
        if not key is String or key.is_empty() or key.length() > 240 or not chunks[key] is int or chunks[key] not in [1, 2]:
            return false
    for key in objects:
        if not key is String or key.is_empty() or key.length() > 320 or not objects[key] is int or objects[key] not in [1, 2]:
            return false
    lease_epoch = epoch
    lease_owners = chunks.duplicate()
    lease_objects = objects.duplicate()
    return true

# Ownership maps travel as a diff against the previous epoch. A key that left the map has value 0.
static func owner_diff(prev: Dictionary, next: Dictionary) -> Dictionary:
    var diff: Dictionary = {}
    for key in next:
        if prev.get(key) != next[key]:
            diff[key] = next[key]
    for key in prev:
        if not next.has(key):
            diff[key] = 0
    return diff

static func apply_diff(prev: Dictionary, diff: Dictionary) -> Dictionary:
    var result: Dictionary = prev.duplicate()
    for key in diff:
        if diff[key] == 0:
            result.erase(key)
        else:
            result[key] = diff[key]
    return result

# Insertion order does not matter: both peers compare this hash after applying a diff.
static func map_hash(map: Dictionary) -> String:
    var keys: Array = map.keys()
    keys.sort()
    var lines := PackedStringArray()
    for key in keys:
        lines.append("%s=%s" % [key, map[key]])
    return "
".join(lines).sha256_text()

func object_owner(uuid: String, instance: String, chunk: Vector3i) -> int:
    return int(lease_objects.get(instance + "|" + uuid, leased_owner(chunk, instance)))

static func batches(chunks: Array) -> Array:
    var result: Array = []
    for start in range(0, chunks.size(), MAX_CHUNKS):
        result.append(chunks.slice(start, start + MAX_CHUNKS))
    return result

static func _chunk_fingerprint(root: Dictionary, prefix: String, chunk: Vector3i) -> int:
    var channels: Array = []
    for channel in ["chunk_block", "chunk_water", "chunk_water_awake", "chunk_fire"]:
        channels.append(root.get(prefix + channel, {}).get(chunk))
    return hash(channels)

static func owner(chunk: Vector3i, instance: String, host: Dictionary, guest: Dictionary) -> int:
    var center := Vector3(chunk) + Vector3(8, 8, 8)
    var host_here: bool = host.get("dimension_instance_key") == instance
    var guest_here: bool = guest.get("dimension_instance_key") == instance and guest.get("active", false)
    if host_here and center.distance_to(host.get("position", Vector3.INF)) <= HOST_RADIUS:
        return 1
    if guest_here and center.distance_to(guest.get("position", Vector3.INF)) <= RADIUS:
        return 2
    return 1

static func chunk_key(instance: String, chunk: Vector3i) -> String:
    return "%s:%d,%d,%d" % [instance, chunk.x, chunk.y, chunk.z]

func changed(instance: String, root: Dictionary, prefix: String) -> Array:
    var chunks: Array = []
    for chunk in root.get(prefix + "chunk_block", {}):
        var fingerprint: int = _chunk_fingerprint(root, prefix, chunk)
        var key: String = chunk_key(instance, chunk)
        if fingerprints.get(key) != fingerprint:
            chunks.append(chunk)
    return chunks

func accept(instance: String, root: Dictionary, prefix: String) -> Dictionary:
    var versions: Dictionary = {}
    for chunk in changed(instance, root, prefix):
        var key: String = chunk_key(instance, chunk)
        fingerprints[key] = _chunk_fingerprint(root, prefix, chunk)
        revisions[key] = int(revisions.get(key, 0)) + 1
    for chunk in root.get(prefix + "chunk_block", {}):
        var key: String = chunk_key(instance, chunk)
        versions[key] = int(revisions.get(key, 0))
    return versions

func current(instance: String, root: Dictionary, prefix: String, proposed: Dictionary) -> bool:
    for chunk in root.get(prefix + "chunk_block", {}):
        var key: String = chunk_key(instance, chunk)
        if int(proposed.get(key, 0)) != int(revisions.get(key, 0)):
            return false
    return true

func seed(instance: String, root: Dictionary, prefix: String, versions: Dictionary) -> void:
    for chunk in root.get(prefix + "chunk_block", {}):
        var key: String = chunk_key(instance, chunk)
        fingerprints[key] = _chunk_fingerprint(root, prefix, chunk)
        revisions[key] = int(versions.get(key, 0))

# Versions from the previous owner without a fingerprint: this side's next routine checkpoint sees the chunk as changed and makes it durable.
func seed_versions(instance: String, root: Dictionary, prefix: String, versions: Dictionary) -> void:
    for chunk in root.get(prefix + "chunk_block", {}):
        var key: String = chunk_key(instance, chunk)
        revisions[key] = int(versions.get(key, 0))
