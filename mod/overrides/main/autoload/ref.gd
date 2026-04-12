extends Node


var coop_manager
var coop_native_patch
var command_chat_manager


@onready var main = get_tree().get_root().get_node("Main")
@onready var world = get_tree().get_root().get_node("Main/World")
@onready var weather = get_tree().get_root().get_node("Main/World/Weather")
@onready var entity_spawner = get_tree().get_root().get_node("Main/World/EntitySpawner")
@onready var player = get_tree().get_root().get_node("Main/Player")
@onready var player_camera = get_tree().get_root().get_node("Main/Player/%Camera3D")

@onready var sun = get_tree().get_root().get_node("Main/World/Sun")
@onready var sun_box = get_tree().get_root().get_node("Main/World/SunBoxOffset/SunBox")
@onready var sky = get_tree().get_root().get_node("Main/World/SkyBoxOffset/Sky")

@onready var save_file_manager = get_tree().get_root().get_node("Main/%SaveFileManager")
@onready var audio_manager = get_tree().get_root().get_node("Main/AudioManager")
@onready var ambience_manager = get_tree().get_root().get_node("Main/AudioManager/AmbienceManager")
@onready var biome_music_manager = get_tree().get_root().get_node("Main/%BiomeMusicManager")
@onready var preserve_node_manager = get_tree().get_root().get_node("Main/%PreserveNodeManager")
@onready var plot_manager = get_tree().get_root().get_node("Main/%PlotManager")
@onready var boss_manager = get_tree().get_root().get_node("Main/%BossManager")
@onready var discovery_manager = get_tree().get_root().get_node("Main/%DiscoveryManager")

@onready var player_inventory = get_tree().get_root().get_node("Main/%Player/%Inventory")
@onready var player_hotbar = get_tree().get_root().get_node("Main/%Player/%Hotbar")
@onready var player_fuser = get_tree().get_root().get_node("Main/%Player/%Fuser")
@onready var player_fusion_source = get_tree().get_root().get_node("Main/%Player/%FusionSource")
@onready var player_fusion_result = get_tree().get_root().get_node("Main/%Player/%FusionResult")
@onready var player_equipment = get_tree().get_root().get_node("Main/%Player/%Equipment")

@onready var ui = get_tree().get_root().get_node("Main/UI")
@onready var cutscene_layer = get_tree().get_root().get_node("Main/CutsceneLayer")
@onready var trans = get_tree().get_root().get_node("Main/TransitionLayer/Transition")
@onready var environment = get_tree().get_root().get_node("Main/World/MainEnvironment")
@onready var water_filter = get_tree().get_root().get_node("Main/UI/WaterFilter")
@onready var game_menu = get_tree().get_root().get_node("Main/UI/GameMenu")
@onready var cutscene_menu = get_tree().get_root().get_node("Main/UI/CutsceneMenu")
@onready var world_edit_menu = get_tree().get_root().get_node("Main/UI/WorldEditMenu")
@onready var level_up_menu = get_tree().get_root().get_node("Main/UI/LevelUpMenu")
@onready var settings_menu = get_tree().get_root().get_node("Main/UI/SettingsMenu")
@onready var bead_get_menu = get_tree().get_root().get_node("Main/UI/BeadGetMenu")
@onready var dither_filter = get_tree().get_root().get_node("Main/UI/%DitheringFilter")
@onready var shader_loader = get_tree().get_root().get_node("Main/ShaderLoader")
@onready var splash_layer = get_tree().get_root().get_node("Main/SplashLayer")
@onready var on_screen_keyboard = get_tree().get_root().get_node("Main/%OnscreenKeyboard")
@onready var save_notifier = get_tree().get_root().get_node("Main/%SaveNotifier")


func _enter_tree() -> void:
    _bootstrap_native_patch()


func _ready() -> void:
    print("[lucid-blocks-coop] Ref override loaded")
    call_deferred("_bootstrap_coop")
    call_deferred("_bootstrap_command_chat")


func _bootstrap_coop() -> void:
    if has_node("LucidBlocksCoop"):
        coop_manager = get_node("LucidBlocksCoop")
        return

    var coop_script = load("res://coop_mod/coop_manager.gd")
    if coop_script == null:
        push_error("[lucid-blocks-coop] Failed to load coop manager script")
        return

    coop_manager = coop_script.new()
    coop_manager.name = "LucidBlocksCoop"
    add_child(coop_manager)


func _bootstrap_native_patch() -> void:
    var executable_path: String = OS.get_executable_path()
    if executable_path.is_empty():
        return

    var native_patch_dir: String = executable_path.get_base_dir().path_join("coop-native-patch")
    var extension_path: String = native_patch_dir.path_join("coop_native_patch.gdextension")
    if not FileAccess.file_exists(extension_path):
        return

    if not GDExtensionManager.is_extension_loaded(extension_path):
        var status := GDExtensionManager.load_extension(extension_path)
        print("[lucid-blocks-coop] Native patch extension load status: %s" % str(status))

    if ClassDB.class_exists("CoopNativePatch"):
        coop_native_patch = ClassDB.instantiate("CoopNativePatch")
        if coop_native_patch != null and coop_native_patch.has_method("get_status"):
            print("[lucid-blocks-coop] Native patch status: %s" % str(coop_native_patch.call("get_status")))
            _apply_native_patch_config(native_patch_dir.path_join("patch_config.json"))


func _apply_native_patch_config(config_path: String) -> void:
    if coop_native_patch == null:
        return

    var enabled: bool = true
    var instance_radius_cap: int = 192
    var render_distance: int = 192
    if FileAccess.file_exists(config_path):
        var config_file := FileAccess.open(config_path, FileAccess.READ)
        if config_file != null:
            var parsed = JSON.parse_string(config_file.get_as_text())
            if typeof(parsed) == TYPE_DICTIONARY:
                var config: Dictionary = parsed
                enabled = bool(config.get("enabled", enabled))
                instance_radius_cap = maxi(96, int(config.get("instance_radius_cap", instance_radius_cap)))
                render_distance = maxi(96, int(config.get("instantiate_chunks_render_distance", render_distance)))

    if not enabled:
        return

    render_distance = maxi(render_distance, instance_radius_cap)
    if render_distance % 16 != 0:
        render_distance = (int(render_distance / 16) + 1) * 16

    if not coop_native_patch.has_method("patch_world_streaming_limits"):
        push_error("[lucid-blocks-coop] Loaded native patch extension is missing patch_world_streaming_limits")
        return

    var ok := bool(coop_native_patch.call("patch_world_streaming_limits", instance_radius_cap, render_distance))
    if ok and coop_native_patch.has_method("install_multi_region_radius_hooks"):
        var hook_ok := bool(coop_native_patch.call("install_multi_region_radius_hooks"))
        print("[lucid-blocks-coop] Native multi-region hook install=%s" % str(hook_ok))

    print("[lucid-blocks-coop] Native patch applied=%s cap=%d render_distance=%d" % [str(ok), instance_radius_cap, render_distance])


func _bootstrap_command_chat() -> void:
    if has_node("LucidBlocksCommandChat"):
        command_chat_manager = get_node("LucidBlocksCommandChat")
        return

    var chat_script = load("res://chat_mod/command_chat_manager.gd")
    if chat_script == null:
        return

    command_chat_manager = chat_script.new()
    command_chat_manager.name = "LucidBlocksCommandChat"
    add_child(command_chat_manager)
