class_name PreserveNodeManager extends Node


var exiting_game: bool = false
var is_saving: bool = false
var default_node_disabled: bool = false

var chunk_to_uuid_map: Dictionary[Vector3i, PackedStringArray]
var node_to_uuid_map: Dictionary[Node, String]
var keep_on_next_removal: Dictionary[Node, bool]


func _ready() -> void :
    Ref.world.chunk_loaded.connect(_on_chunk_loaded)
    get_tree().get_root().child_entered_tree.connect(_on_child_entered_tree)
    get_tree().get_root().child_exiting_tree.connect(_on_child_exiting_tree)


func _is_guest_replica_mode() -> bool:
    return Ref.coop_manager != null \
        and Ref.coop_manager.has_active_session() \
        and not multiplayer.is_server()


func _on_child_entered_tree(node: Node) -> void :
    if _is_guest_replica_mode():
        return
    if node.is_in_group("preserve") or node.is_in_group("preserve_but_delete_on_unload") or node.is_in_group("preserve_on_modified_chunks_only"):
        var new_object: ChunkUnloadDetect = ChunkUnloadDetect.new()
        new_object.node = node
        get_tree().get_root().add_child(new_object)
        Ref.world.chunk_unloaded.connect(new_object._on_chunk_unloaded)
        node.tree_exited.connect(new_object._on_node_deleted)
        if not node in node_to_uuid_map:
            node_to_uuid_map[node] = UUID.v4()
        node.disabled = default_node_disabled


func _on_child_exiting_tree(node: Node) -> void :
    if exiting_game or _is_guest_replica_mode():
        return
    if node.is_in_group("preserve") or node.is_in_group("preserve_but_delete_on_unload") or node.is_in_group("preserve_on_modified_chunks_only"):
        var uuid: String = node_to_uuid_map[node]
        node_to_uuid_map.erase(node)
        if node in keep_on_next_removal:
            keep_on_next_removal.erase(node)
            return
        Ref.save_file_manager.loaded_file.erase_data("node/%s" % uuid)


func _on_chunk_loaded(position: Vector3i) -> void :
    if _is_guest_replica_mode():
        return
    if not Ref.world.is_position_loaded(position):
        return

    if position in chunk_to_uuid_map:
        for uuid in chunk_to_uuid_map[position]:
            var path: String = Ref.save_file_manager.loaded_file.get_data("node/%s/file_path" % uuid, "")
            if path == "":
                continue
            var scene: PackedScene = load(path)
            if scene == null:
                printerr("Path at ", path, " no longer exists")
                continue

            var node: Node = scene.instantiate()
            node_to_uuid_map[node] = uuid
            get_tree().get_root().add_child(node)
            node.preserve_load(Ref.save_file_manager.loaded_file, uuid)

        chunk_to_uuid_map.erase(position)


func register_node(node: Node) -> void :
    var chunk_position: Vector3i = Ref.world.snap_to_chunk(node.global_position)
    var uuid: String = node_to_uuid_map[node]

    if not chunk_position in chunk_to_uuid_map:
        chunk_to_uuid_map[chunk_position] = PackedStringArray()

    chunk_to_uuid_map[chunk_position].append(uuid)


func unregister_node(node: Node) -> void :
    var chunk_position: Vector3i = Ref.world.snap_to_chunk(node.global_position)
    var uuid: String = node_to_uuid_map[node]

    if not chunk_position in chunk_to_uuid_map:
        return

    var idx: int = chunk_to_uuid_map[chunk_position].find(uuid)
    if idx > -1:
        chunk_to_uuid_map[chunk_position].remove_at(idx)


func register_all_nodes() -> void :
    if _is_guest_replica_mode():
        return
    for node in get_tree().get_nodes_in_group("preserve") + get_tree().get_nodes_in_group("preserve_but_delete_on_unload"):
        register_node(node)


func unregister_all_nodes() -> void :
    if _is_guest_replica_mode():
        return
    for node in get_tree().get_nodes_in_group("preserve") + get_tree().get_nodes_in_group("preserve_but_delete_on_unload") + get_tree().get_nodes_in_group("preserve_on_modified_chunks_only"):
        unregister_node(node)


func enable_all_nodes() -> void :
    if _is_guest_replica_mode():
        default_node_disabled = true
        return
    for node in get_tree().get_nodes_in_group("preserve") + get_tree().get_nodes_in_group("preserve_but_delete_on_unload") + get_tree().get_nodes_in_group("preserve_on_modified_chunks_only"):
        node.disabled = false
    default_node_disabled = false


func save_file(file: SaveFile) -> void :
    if _is_guest_replica_mode():
        return
    is_saving = true
    register_all_nodes()

    for node in get_tree().get_nodes_in_group("preserve") + get_tree().get_nodes_in_group("preserve_but_delete_on_unload") + get_tree().get_nodes_in_group("preserve_on_modified_chunks_only"):
        var uuid: String = node_to_uuid_map[node]

        if node.is_in_group("preserve_on_modified_chunks_only"):
            if Ref.world.is_chunk_modified(node.global_position):
                register_node(node)
            else:
                continue

        node.preserve_save(file, uuid)
        file.set_data("node/%s/file_path" % uuid, node.scene_file_path)

    file.set_data("world/chunk_to_uuid_map", chunk_to_uuid_map.duplicate(true))
    unregister_all_nodes()
    is_saving = false


func load_file(file: SaveFile) -> void :
    var empty: Dictionary[Vector3i, PackedStringArray] = {}
    if _is_guest_replica_mode():
        chunk_to_uuid_map = empty
        return
    chunk_to_uuid_map = file.get_data("world/chunk_to_uuid_map", empty).duplicate(true)


func enter_game() -> void :
    exiting_game = false
    default_node_disabled = true
    node_to_uuid_map.clear()
    keep_on_next_removal.clear()
    if _is_guest_replica_mode():
        chunk_to_uuid_map.clear()


func exit_game() -> void :
    exiting_game = true
    default_node_disabled = true
    chunk_to_uuid_map.clear()
    node_to_uuid_map.clear()
    keep_on_next_removal.clear()

    for node in get_tree().get_nodes_in_group("preserve") + get_tree().get_nodes_in_group("preserve_but_delete_on_unload") + get_tree().get_nodes_in_group("preserve_on_modified_chunks_only"):
        node.queue_free.call_deferred()
