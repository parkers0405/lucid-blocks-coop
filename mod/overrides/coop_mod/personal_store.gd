extends RefCounted

const Files = preload("res://coop_mod/region_checkpoint.gd")
const InstanceEntities = preload("res://coop_mod/instance_entities.gd")
const SLOTS: int = 21
const MAX_LEDGER_BYTES: int = 32 * 1024 * 1024
const MAX_RESPAWNS: int = 4096
const MAX_RESPAWN_BYTES: int = 256 * 1024
var files := Files.new()

static func stack_limit(id: int, limits: Dictionary) -> int:
    return int(limits.get(id, 0))

static func valid_state(state: Dictionary) -> bool:
    if var_to_bytes(state).size() > 8388608:
        return false
    var node = state.get("node", {})
    if not node is Dictionary or not node.get("player", {}) is Dictionary:
        return false
    var player: Dictionary = node.get("player", {})
    for name_value in ["Inventory", "Hotbar", "Equipment", "FusionSource", "FusionResult"]:
        if not player.has(name_value):
            continue
        var inventory = player[name_value]
        if not inventory is Dictionary or not inventory.get("items") is Array or not inventory.get("capacity") is int:
            return false
        var items: Array = inventory["items"]
        if inventory["capacity"] < 0 or inventory["capacity"] > 128 or items.size() != inventory["capacity"] * 2:
            return false
        for index in range(0, items.size(), 2):
            var item = items[index]
            if not item is PackedInt32Array or not items[index + 1] is Vector3i:
                return false
            if not item.is_empty() and (item.size() != 3 or item[0] <= 0 or item[1] <= 0 or item[2] < 0):
                return false
    return true

static func _profile_key(path: String) -> String:
    var name: String = path.get_file()
    var key: String = name.get_basename()
    if name.get_extension() != "bin" or key == "ledger" or not Files.valid_component(key):
        return ""
    return key

static func storage_path(path: String) -> String:
    return path.get_base_dir().path_join("ledger.bin")

static func _new_profile() -> Dictionary:
    var chest: Array = []
    chest.resize(SLOTS)
    return {"revision": 0, "state": {}, "chest": chest, "receipts": []}

static func _valid_profile(record: Variant) -> bool:
    if not record is Dictionary:
        return false
    if not record.get("revision") is int or not record.get("state") is Dictionary:
        return false
    if not record.get("chest") is Array or record["chest"].size() != SLOTS:
        return false
    if not record.get("receipts") is Array:
        return false
    if record["revision"] < 0 or record["receipts"].size() > 32 or not valid_state(record["state"]):
        return false
    for receipt in record["receipts"]:
        if not receipt is String or receipt.length() != 64 or not receipt.is_valid_hex_number():
            return false
    for slot in record["chest"]:
        if slot == null:
            continue
        if not slot is Dictionary or not slot.get("item") is PackedInt32Array or not slot.get("position") is Vector3i:
            return false
        var item: PackedInt32Array = slot["item"]
        if item.size() != 3 or item[0] <= 0 or item[1] <= 0 or item[2] < 0:
            return false
    return true

static func _valid_uuid(value: Variant) -> bool:
    return value is String and value.length() == 36 and value.replace("-", "").is_valid_hex_number()

static func valid_respawns(value: Variant) -> bool:
    if not value is Dictionary or value.size() > MAX_RESPAWNS or var_to_bytes(value).size() > MAX_RESPAWN_BYTES:
        return false
    for position in value:
        if not position is Vector3i or not value[position] is bool or value[position] != true:
            return false
    return true

static func respawn_chunk(position: Vector3i) -> Vector3i:
    return Vector3i(floori(position.x / 16.0) * 16, floori(position.y / 16.0) * 16, floori(position.z / 16.0) * 16)

static func valid_respawn_update(update: Dictionary) -> bool:
    if not valid_respawns(update.get("positions")):
        return false
    if not update.get("chunks") is Array or update["chunks"].size() > 8192:
        return false
    if var_to_bytes(update).size() > 512 * 1024:
        return false
    for key in update:
        if key not in ["positions", "chunks", "initial"]:
            return false
    if update.has("initial") and not valid_respawns(update["initial"]):
        return false
    var chunks: Dictionary = {}
    for chunk in update["chunks"]:
        if not chunk is Vector3i or respawn_chunk(chunk) != chunk or chunks.has(chunk):
            return false
        chunks[chunk] = true
    for position in update["positions"]:
        if not chunks.has(respawn_chunk(position)):
            return false
    return true

static func _valid_instance(record: Variant, profiles: Dictionary) -> bool:
    if not record is Dictionary or not record.get("dimension") is String or not Files.valid_component(record["dimension"]):
        return false
    if record.has("respawn_positions") and not valid_respawns(record["respawn_positions"]):
        return false
    for field in ["nodes", "owners", "observed", "tombstones"]:
        if not record.get(field) is Dictionary:
            return false
    var nodes: Dictionary = record["nodes"]
    var owners: Dictionary = record["owners"]
    var observed: Dictionary = record["observed"]
    var tombstones: Dictionary = record["tombstones"]
    if nodes.size() != owners.size() or nodes.size() > 4096 or tombstones.size() > 32768:
        return false
    for owner in observed:
        if not profiles.has(owner) or not observed[owner] is Dictionary:
            return false
        for uuid in observed[owner]:
            if not _valid_uuid(uuid) or observed[owner][uuid] != true:
                return false
    for uuid in tombstones:
        if not _valid_uuid(uuid) or tombstones[uuid] != true or nodes.has(uuid):
            return false
    for uuid in nodes:
        var bundle = nodes[uuid]
        if not _valid_uuid(uuid) or not bundle is Dictionary or bundle.get("uuid") != uuid or not bundle.get("scene_path") is String:
            return false
        var scene: String = bundle["scene_path"]
        if not scene.begins_with("res://") or scene.length() > 512 or not InstanceEntities.valid_bundle(bundle, record["dimension"], {scene: true}):
            return false
        var owner = owners.get(uuid)
        if not owner is String or not profiles.has(owner) or not observed.get(owner, {}).has(uuid):
            return false
    return true

static func _valid_ledger(record: Variant) -> bool:
    if not record is Dictionary or not record.get("schema") is int or record.get("schema") != 1:
        return false
    if not record.get("profiles") is Dictionary or not record.get("instances") is Dictionary:
        return false
    if record["profiles"].size() > 128 or record["instances"].size() > 128:
        return false
    if record.has("lease"):
        var lease = record["lease"]
        if not lease is Dictionary or not lease.get("epoch") is int or lease["epoch"] <= 0:
            return false
        if not lease.get("chunks") is Dictionary or not lease.get("objects") is Dictionary:
            return false
        if lease["chunks"].size() > 32768 or lease["objects"].size() > 8192:
            return false
        for group in ["chunks", "objects"]:
            for key in lease[group]:
                if not key is String or key.is_empty() or key.length() > 320 or not lease[group][key] is int or lease[group][key] not in [1, 2]:
                    return false
    for key in record["profiles"]:
        if not key is String or not Files.valid_component(key) or not _valid_profile(record["profiles"][key]):
            return false
    for instance in record["instances"]:
        if not instance is String or not Files.valid_component(instance) or not _valid_instance(record["instances"][instance], record["profiles"]):
            return false
    return true

func read_ledger(path: String) -> Dictionary:
    # Old per-player files need migration before we can use the shared ledger.
    if _profile_key(path).is_empty() or FileAccess.file_exists(path):
        return {}
    var physical: String = storage_path(path)
    if not FileAccess.file_exists(physical):
        return {"schema": 1, "profiles": {}, "instances": {}}
    var bytes: PackedByteArray = files._read_bytes(physical)
    if bytes.size() < 4 or bytes.size() > MAX_LEDGER_BYTES:
        return {}
    var ledger = bytes_to_var(bytes)
    return ledger if _valid_ledger(ledger) else {}

func profile_exists(path: String) -> bool:
    var ledger: Dictionary = read_ledger(path)
    return not ledger.is_empty() and ledger["profiles"].has(_profile_key(path))

func read_profile(path: String) -> Dictionary:
    var ledger: Dictionary = read_ledger(path)
    return {} if ledger.is_empty() else ledger["profiles"].get(_profile_key(path), _new_profile())

func _write_ledger(path: String, ledger: Dictionary) -> bool:
    if not _valid_ledger(ledger):
        return false
    var bytes: PackedByteArray = var_to_bytes(ledger)
    if bytes.size() > MAX_LEDGER_BYTES or DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
        return false
    return files._replace_file(storage_path(path), bytes)

func commit(path: String, record: Dictionary) -> bool:
    var ledger: Dictionary = read_ledger(path)
    if ledger.is_empty() or not _valid_profile(record):
        return false
    ledger["profiles"][_profile_key(path)] = record.duplicate(true)
    return _write_ledger(path, ledger)

# An empty world is valid. A broken save is not.
func instance_bundles(path: String, instance: String) -> Dictionary:
    var ledger: Dictionary = read_ledger(path)
    if ledger.is_empty() or not Files.valid_component(instance):
        return {"ok": false, "bundles": []}
    var record: Dictionary = ledger["instances"].get(instance, {})
    return {"ok": true, "bundles": record.get("nodes", {}).values().duplicate(true)}

func instance_respawns(path: String, instance: String) -> Dictionary:
    var ledger: Dictionary = read_ledger(path)
    if ledger.is_empty() or not Files.valid_component(instance):
        return {"ok": false, "present": false, "positions": {}}
    var record: Dictionary = ledger["instances"].get(instance, {})
    return {"ok": true, "present": record.has("respawn_positions"), "positions": record.get("respawn_positions", {}).duplicate(true)}

func save_checkpoint(path: String, state: Dictionary, revision: int, instance: String, dimension: String, bundles: Array, allowed_scenes: Dictionary, respawn_update: Dictionary = {}, skip_unchanged: bool = false, expected_lease: int = -1) -> Dictionary:
    var ledger: Dictionary = read_ledger(path)
    if ledger.is_empty() or not valid_state(state) or not Files.valid_component(instance) or not Files.valid_component(dimension) or bundles.size() > 512 or var_to_bytes(bundles).size() > 8388608:
        return {}
    if expected_lease >= 0 and int(ledger.get("lease", {}).get("epoch", 0)) != expected_lease:
        return {}
    var original: Dictionary = ledger.duplicate(true) if skip_unchanged else {}
    var key: String = _profile_key(path)
    var profile: Dictionary = ledger["profiles"].get(key, _new_profile())
    if profile["revision"] != revision:
        return {}
    var record: Dictionary = ledger["instances"].get(instance, {"dimension": dimension, "nodes": {}, "owners": {}, "observed": {}, "tombstones": {}})
    if record["dimension"] != dimension:
        return {}
    if not respawn_update.is_empty():
        if not valid_respawn_update(respawn_update) or (respawn_update.has("initial") and record.has("respawn_positions")):
            return {}
        var positions: Dictionary = record.get("respawn_positions", respawn_update.get("initial", {})).duplicate(true)
        var coverage: Dictionary = {}
        for chunk in respawn_update["chunks"]:
            coverage[chunk] = true
        for position in positions.keys():
            if coverage.has(respawn_chunk(position)) and not respawn_update["positions"].has(position):
                positions.erase(position)
        positions.merge(respawn_update["positions"], true)
        record["respawn_positions"] = positions
    var incoming: Dictionary = {}
    for bundle in bundles:
        if not InstanceEntities.valid_bundle(bundle, dimension, allowed_scenes) or incoming.has(bundle["uuid"]):
            return {}
        incoming[bundle["uuid"]] = bundle.duplicate(true)
    var nodes: Dictionary = record["nodes"]
    var owners: Dictionary = record["owners"]
    var observed: Dictionary = record["observed"].get(key, {})
    var tombstones: Dictionary = record["tombstones"]
    for uuid in owners.keys():
        if owners[uuid] == key and not incoming.has(uuid):
            nodes.erase(uuid)
            owners.erase(uuid)
            tombstones[uuid] = true
    for uuid in incoming:
        # Ignore old saves from a player who no longer owns the object.
        if tombstones.has(uuid) or (owners.has(uuid) and owners[uuid] != key):
            continue
        nodes[uuid] = incoming[uuid]
        owners[uuid] = key
        observed[uuid] = true
    record["observed"][key] = observed
    ledger["instances"][instance] = record
    var normalized: Dictionary = state.duplicate(true)
    normalized.erase("_coop_revision")
    var previous_state: Dictionary = profile["state"].duplicate(true)
    previous_state.erase("_coop_revision")
    if skip_unchanged and normalized == previous_state and ledger == original:
        return profile
    profile["state"] = state.duplicate(true)
    profile["revision"] += 1
    ledger["profiles"][key] = profile
    return profile if _write_ledger(path, ledger) else {}

# Save the new owners and their lease number together.
func commit_lease(path: String, epoch: int, chunks: Dictionary, objects: Dictionary, transfers: Array) -> bool:
    var ledger: Dictionary = read_ledger(path)
    if ledger.is_empty() or epoch <= int(ledger.get("lease", {}).get("epoch", 0)) or chunks.size() > 32768 or objects.size() > 8192:
        return false
    for transfer in transfers:
        if not transfer is Dictionary or not Files.valid_component(str(transfer.get("new", ""))):
            return false
        var record: Dictionary = ledger["instances"].get(transfer.get("instance"), {})
        var uuid = transfer.get("uuid")
        if record.is_empty() or not record["nodes"].has(uuid) or record["owners"].get(uuid) != transfer.get("old") or record["tombstones"].has(uuid):
            return false
        var owner: String = transfer["new"]
        if not ledger["profiles"].has(owner):
            ledger["profiles"][owner] = _new_profile()
        record["owners"][uuid] = owner
        if not record["observed"].has(owner):
            record["observed"][owner] = {}
        record["observed"][owner][uuid] = true
    ledger["lease"] = {"epoch": epoch, "chunks": chunks.duplicate(), "objects": objects.duplicate()}
    return _write_ledger(path, ledger)

func collect_drop(path: String, revision: int, request: String, instance: String, uuid: String, stack_limit: Callable) -> Dictionary:
    var ledger: Dictionary = read_ledger(path)
    if ledger.is_empty() or request.length() != 64 or not request.is_valid_hex_number():
        return {}
    var profile: Dictionary = ledger["profiles"].get(_profile_key(path), {})
    if profile.is_empty():
        return {}
    if profile["receipts"].has(request):
        return _pickup_result(profile, ledger["instances"].get(instance, {}), uuid)
    var record: Dictionary = ledger["instances"].get(instance, {})
    if profile["revision"] != revision or record.is_empty() or not record["nodes"].has(uuid):
        return {}
    var bundle: Dictionary = record["nodes"][uuid]
    if bundle.get("scene_path") != "res://main/items/dropped_item/dropped_item.tscn":
        return {}
    var node: Dictionary = bundle["save_data"][record["dimension"]]["node"][uuid]
    var source: PackedInt32Array = PackedInt32Array()
    var position: Vector3i = Vector3i.ZERO
    var source_items: Array = []
    for entry in node.values():
        if entry is Dictionary and entry.get("capacity") == 1 and entry.get("items") is Array and entry["items"].size() == 2:
            if not source.is_empty() or not entry["items"][0] is PackedInt32Array or not entry["items"][1] is Vector3i:
                return {}
            source = entry["items"][0].duplicate()
            source_items = entry["items"]
            position = entry["items"][1]
    if source.size() != 3 or source[0] <= 0 or source[1] <= 0:
        return {}
    var maximum: int = int(stack_limit.call(source[0]))
    if maximum <= 0 or source[1] > maximum:
        return {}
    var remaining: int = source[1]
    # Fill matching stacks before empty slots; leave overflow in the world.
    for fill_empty_slots in [false, true]:
        for name_value in ["Hotbar", "Inventory"]:
            var inventory: Dictionary = profile["state"].get("node", {}).get("player", {}).get(name_value, {})
            var items: Array = inventory.get("items", [])
            for index in range(0, items.size(), 2):
                var item: PackedInt32Array = items[index]
                if item.is_empty() != fill_empty_slots:
                    continue
                if not item.is_empty() and (item[0] != source[0] or item[2] != source[2] or items[index + 1] != position):
                    continue
                var existing: int = 0 if item.is_empty() else item[1]
                var amount: int = mini(remaining, maxi(0, maximum - existing))
                if amount == 0:
                    continue
                var updated: PackedInt32Array = source.duplicate()
                updated[1] = existing + amount
                items[index] = updated
                items[index + 1] = position
                remaining -= amount
    if remaining == source[1]:
        return {}
    if remaining > 0:
        source[1] = remaining
        source_items[0] = source
    else:
        record["nodes"].erase(uuid)
        record["owners"].erase(uuid)
        record["tombstones"][uuid] = true
    profile["revision"] += 1
    profile["receipts"].append(request)
    if profile["receipts"].size() > 32:
        profile["receipts"].pop_front()
    return _pickup_result(profile, record, uuid) if _write_ledger(path, ledger) else {}

static func _pickup_result(profile: Dictionary, record: Dictionary, uuid: String) -> Dictionary:
    var result: Dictionary = profile.duplicate(true)
    result["_coop_pickup_bundle"] = record.get("nodes", {}).get(uuid, {}).duplicate(true)
    return result

# Save the inventory and chest together so a failed write cannot lose items.
func transfer(path: String, revision: int, request: String, inventory_name: String, inventory_index: int, chest_index: int, amount: int, deposit: bool, stack_limit: Callable) -> Dictionary:
    var record: Dictionary = read_profile(path)
    if record.is_empty():
        return {}
    if record["receipts"].has(request):
        return record
    if record["revision"] != revision or request.length() != 64 or not request.is_valid_hex_number():
        return {}
    if inventory_name not in ["Inventory", "Hotbar"] or inventory_index < 0:
        return {}
    if chest_index < 0 or chest_index >= SLOTS or amount <= 0:
        return {}
    var inventory = record["state"].get("node", {}).get("player", {}).get(inventory_name, {})
    var items = inventory.get("items", [])
    if not items is Array or inventory_index * 2 + 1 >= items.size():
        return {}
    var player_item = items[inventory_index * 2]
    var player_position: Vector3i = items[inventory_index * 2 + 1]
    var chest_slot = record["chest"][chest_index]
    var chest_item = null
    var chest_position: Vector3i = Vector3i.ZERO
    if chest_slot is Dictionary:
        chest_item = chest_slot.get("item")
        chest_position = chest_slot.get("position", Vector3i.ZERO)

    var source = player_item
    var destination = chest_item
    var source_position: Vector3i = player_position
    var destination_position: Vector3i = player_position
    if deposit:
        if chest_slot is Dictionary:
            destination_position = chest_position
    else:
        source = chest_item
        destination = player_item
        source_position = chest_position

    if not source is PackedInt32Array or source.size() != 3 or source[1] < amount:
        return {}
    var existing: int = 0
    if destination != null:
        if not destination is PackedInt32Array:
            return {}
        if not destination.is_empty():
            if destination.size() != source.size() or destination[0] != source[0] or destination.slice(2) != source.slice(2):
                return {}
            existing = destination[1]
    if existing > 0 and source_position != destination_position:
        return {}
    var maximum: int = int(stack_limit.call(source[0]))
    if maximum <= 0 or source[1] > maximum or existing + amount > maximum:
        return {}
    var moved: PackedInt32Array = source.duplicate()
    moved[1] = existing + amount
    var remaining: PackedInt32Array = source.duplicate()
    remaining[1] -= amount
    if deposit:
        record["chest"][chest_index] = {"item": moved, "position": source_position}
        items[inventory_index * 2] = remaining if remaining[1] > 0 else PackedInt32Array()
    else:
        items[inventory_index * 2] = moved
        items[inventory_index * 2 + 1] = source_position
        record["chest"][chest_index] = {"item": remaining, "position": source_position} if remaining[1] > 0 else null
    record["revision"] += 1
    record["receipts"].append(request)
    if record["receipts"].size() > 32:
        record["receipts"].pop_front()
    return record if commit(path, record) else {}
