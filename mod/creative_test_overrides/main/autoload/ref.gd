extends Node


var coop_manager
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


func _ready() -> void:
    print("[lucid-blocks-coop] Ref override loaded")
    call_deferred("_bootstrap_coop")


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
