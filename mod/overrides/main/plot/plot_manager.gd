class_name PlotManager extends Node

@export var cutscenes: Dictionary[String, PackedScene]
@export var cutscene_prerequisites: Dictionary[String, Prerequisite]

@export var default_cutscene: PackedScene
@export var debug_override_with_default: bool = false
@export var debug_override_with_ending: bool = false
@export var debug_disable_tiamana_gain_from_cutscene: bool = true

@export_category("Special Cutscenes")
@export var ending_cutscene: PackedScene
@export var pre_ending_cutscene: PackedScene
@export var post_ending_cutscene: PackedScene
@export var intro_cutscene: PackedScene

var plot_data: Dictionary
var beads: Dictionary[int, bool]
var watched_cutscenes: Dictionary[String, bool]
var collected_cutscene_blocks: Dictionary[Vector3i, bool]
var tracked_cutscene_blocks: Dictionary[Vector3i, bool]

signal cutscene_block_collected(position: Vector3i)

const MAX_BEADS: int = 13

var current_cutscene: String
var bead_eligible: bool = false
var god_killed: bool = false


func save_file(file: SaveFile) -> void:
    file.set_data("plot/beads", beads, true)
    file.set_data("plot/data", plot_data, true)
    file.set_data("plot/watched_cutscenes", watched_cutscenes, true)
    file.set_data("plot/collected_cutscene_blocks", collected_cutscene_blocks, true)
    file.set_data("plot/tracked_cutscene_blocks", tracked_cutscene_blocks, true)
    file.set_data("plot/current_cutscene", current_cutscene, true)
    file.set_data("plot/ending_completed", god_killed, true)


func load_file(file: SaveFile) -> void:
    god_killed = file.get_data("plot/ending_completed", false, true)

    var default_beads: Dictionary[int, bool] = {}
    beads = file.get_data("plot/beads", default_beads, true)

    plot_data = file.get_data("plot/data", {}, true)

    var default_watched: Dictionary[String, bool] = {}
    watched_cutscenes = file.get_data("plot/watched_cutscenes", default_watched, true)

    var default_collected_cutscene_blocks: Dictionary[Vector3i, bool] = {}
    collected_cutscene_blocks = file.get_data("plot/collected_cutscene_blocks", default_collected_cutscene_blocks, true)

    var default_tracked_cutscene_blocks: Dictionary[Vector3i, bool] = {}
    tracked_cutscene_blocks = file.get_data("plot/tracked_cutscene_blocks", default_tracked_cutscene_blocks, true)

    current_cutscene = file.get_data("plot/current_cutscene", "", true)
    if current_cutscene != "":
        var cutscene_instance: Cutscene = ending_cutscene.instantiate() if current_cutscene == "ending" else cutscenes.get(current_cutscene, default_cutscene).instantiate()
        add_child(cutscene_instance)
        if cutscene_instance.has_method("initialize"):
            await cutscene_instance.initialize()
        else:
            printerr("This cutscene should not be inserted: ", current_cutscene)
            current_cutscene = ""
        cutscene_instance.queue_free()


func serve_cutscene() -> Cutscene:
    var cutscene_scene: PackedScene = default_cutscene
    var cutscene_title: String = "default"

    if not (Ref.main.debug and debug_override_with_default):
        var unwatched_cutscenes: Array[String]
        for cutscene in cutscenes:
            if cutscene_prerequisites.has(cutscene) and not cutscene_prerequisites[cutscene].can_serve():
                continue
            if not cutscene in watched_cutscenes:
                unwatched_cutscenes.append(cutscene)
        if len(unwatched_cutscenes) > 0:
            cutscene_title = unwatched_cutscenes.pick_random()

    if cutscene_title != "default":
        cutscene_scene = cutscenes[cutscene_title]

    if all_beads_collected():
        if god_killed:
            cutscene_title = "default"
            cutscene_scene = default_cutscene
        else:
            cutscene_title = "ending"
            cutscene_scene = ending_cutscene

    var cutscene: Cutscene = cutscene_scene.instantiate()
    cutscene.title = cutscene_title

    insert_cutscene(cutscene)

    return cutscene


func insert_cutscene(cutscene: Cutscene) -> void:
    current_cutscene = cutscene.title
    bead_eligible = current_cutscene != "default" and not current_cutscene in watched_cutscenes
    print("Currently in: %s" % current_cutscene)


func remove_cutscene() -> void:
    print("Cutscene reset")
    current_cutscene = ""
    bead_eligible = false


func mark_cutscene_as_watched() -> void:
    print("Cutscene watched: %s" % current_cutscene)
    if current_cutscene != "default":
        watched_cutscenes[current_cutscene] = true


func mark_block_as_collected(watched_position: Vector3i) -> void:
    collected_cutscene_blocks[watched_position] = true
    cutscene_block_collected.emit(watched_position)


func mark_block_as_tracked(tracked_position: Vector3i) -> void:
    tracked_cutscene_blocks[tracked_position] = true


func is_block_collected(position: Vector3i) -> bool:
    return position in collected_cutscene_blocks


func give_bead() -> void:
    var all_beads: Array[int] = []
    for i in range(MAX_BEADS):
        all_beads.append(i)
    all_beads.shuffle()

    for bead in all_beads:
        if not bead in beads:
            beads[bead] = true
            return


func get_username() -> String:
    if OS.has_environment("USERNAME"):
        return OS.get_environment("USERNAME")
    return "uriel"


func all_beads_collected() -> bool:
    if Ref.main.debug and debug_override_with_ending:
        return true
    var all_true: bool = true
    for bead in beads:
        all_true = all_true and beads[bead]
    return all_true and len(beads) >= MAX_BEADS


func end_game() -> void:
    Ref.game_menu.deactivate()
    Ref.player.disabled = true
    get_tree().paused = true

    Ref.audio_manager.fade_out_sfx()

    await Ref.plot_manager.play_post_ending_cutscene()

    Ref.main.end_ending(true)
    Ref.plot_manager.remove_cutscene()

    if Ref.coop_manager != null:
        await Ref.coop_manager._travel_group_to_dimension_async(int(LucidBlocksWorld.Dimension.NARAKA), true, false)
    else:
        await Ref.main.teleport_to_dimension(LucidBlocksWorld.Dimension.NARAKA, true)


func set_plot_data(property_path: String, val: Variant) -> void:
    SaveFile._set_data(plot_data, property_path, val)


func get_plot_data(property_path: String, default: Variant = null) -> Variant:
    return SaveFile._get_data(plot_data, property_path, default)


func erase_plot_data(property_path: String) -> bool:
    return SaveFile._erase_data(plot_data, property_path)


func play_intro_cutscene() -> void:
    Ref.cutscene_menu.open()
    var cutscene_instance: Cutscene = intro_cutscene.instantiate()
    Ref.cutscene_menu.add_cutscene(cutscene_instance)
    await Ref.trans.close()
    await cutscene_instance.play()
    await Ref.trans.open()
    Ref.cutscene_menu.close()
    cutscene_instance.queue_free()


func play_pre_ending_cutscene() -> void:
    Ref.cutscene_menu.open()
    var cutscene_instance: Cutscene = pre_ending_cutscene.instantiate()
    Ref.cutscene_menu.add_cutscene(cutscene_instance)
    await Ref.trans.close()
    await cutscene_instance.play()
    await Ref.trans.open_fade()
    Ref.cutscene_menu.close()
    cutscene_instance.queue_free()


func play_post_ending_cutscene() -> void:
    Ref.cutscene_menu.open()
    var cutscene_instance: Cutscene = post_ending_cutscene.instantiate()
    Ref.cutscene_menu.add_cutscene(cutscene_instance)
    await Ref.trans.close_fade()
    await cutscene_instance.play()
    await Ref.trans.open()
    Ref.cutscene_menu.close()
    cutscene_instance.queue_free()
