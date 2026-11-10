extends Node

var observed: int = 0
var started: int = 0

func _enter_tree() -> void:
    started = Time.get_ticks_msec()
    print("STARTUP_DIAGNOSTIC_SETUP phase=enter_tree display=", DisplayServer.get_name())
    get_tree().node_added.connect(_observe)
    get_tree().create_timer(5.0, true, false, true).timeout.connect(_finish)
    _snapshot(get_tree().root)

func _snapshot(node: Node) -> void:
    _observe(node)
    for child in node.get_children():
        _snapshot(child)

func _observe(node: Node) -> void:
    var script = node.get_script()
    if script == null:
        return
    observed += 1
    var target: bool = script.resource_path in ["res://main/save_file/save_file_manager.gd", "res://main/shader_compilation/shader_loader.gd", "res://main/main.gd"]
    if observed <= 16 or target:
        var location: String = str(node.get_path()) if node.is_inside_tree() else str(node.name)
        print("STARTUP_NODE ms=", Time.get_ticks_msec() - started, " path=", location, " inside_tree=", node.is_inside_tree(), " class=", node.get_class(), " script=", script.resource_path, " ready=", node.is_node_ready())
        if not node.is_node_ready() and not node.ready.is_connected(_ready_seen.bind(node)):
            node.ready.connect(_ready_seen.bind(node), CONNECT_ONE_SHOT)

func _ready_seen(node: Node) -> void:
    print("STARTUP_READY ms=", Time.get_ticks_msec() - started, " path=", node.get_path(), " script=", node.get_script().resource_path)

func _finish() -> void:
    # The original keyboard owns an unattached helper, also released by the build probe.
    var keyboard = get_node_or_null("/root/Main/UI/OnscreenKeyboard")
    if keyboard != null:
        var helper = keyboard.get("KeyListHandler")
        if is_instance_valid(helper) and helper is Node and not helper.is_inside_tree() and helper.get_script().resource_path == "res://addons/onscreenkeyboard/keylist.gd":
            helper.free()
            keyboard.set("KeyListHandler", null)
    print("STARTUP_DIAGNOSTIC_RESULT nodes=", observed, " elapsed_ms=", Time.get_ticks_msec() - started)
    get_tree().quit(0 if observed > 0 else 1)
