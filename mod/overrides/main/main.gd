class_name Main extends Node


@export var debug: bool = true
@export var demo: bool = false
@export var main_menu_music: AudioStream
@export var firmament_menu_music: AudioStream
@export var death_menu_music: AudioStream
@export var upside_down_block: Block

var creative: bool = false
var upside_down: bool = false
var wrathful_torus: bool = false
var loaded: bool = false
var progression_disabled: bool = false
var in_challenge: bool = false
var in_ending: bool = false

signal game_quit
signal world_loaded
signal new_game_loaded
signal game_playable
signal all_loaded
signal window_focused
signal window_unfocused

func _ready() -> void :
    get_tree().paused = true

    %MainMenu.play_requested.connect(_on_main_menu_play_requested)
    %MainMenu.settings_requested.connect(_on_main_menu_settings_requested)
    %MainMenu.editor_requested.connect(_on_main_menu_editor_requested)

    %GameMenu.quit_requested.connect(_on_game_menu_quit_requested)
    %GameMenu.settings_requested.connect(_on_game_menu_settings_requested)

    %SaveFileMenu.exited.connect(_on_save_file_menu_exited)
    %SaveFileMenu.new_world_requested.connect(_on_save_file_menu_new_world_requested)
    %SaveFileMenu.play_requested.connect(_on_save_file_menu_play_requested)
    %SaveFileMenu.edit_requested.connect(_on_save_file_menu_edit_requested)
    %SaveFileMenu.delete_requested.connect(_on_save_file_menu_delete_requested)
    %SaveFileMenu.firmament_requested.connect(_on_save_file_menu_firmament_requested)

    %FirmamentMenu.exited.connect(_on_firmament_menu_exited)
    %FirmamentMenu.upload_requested.connect(_on_firmament_menu_upload_requested)
    %FirmamentMenu.download_requested.connect(_on_firmament_menu_download_requested)
    %FirmamentMenu.past_uploads_requested.connect(_on_firmament_past_uploads_menu_requested)

    %FirmamentUploadMenu.exited.connect(_on_firmament_upload_menu_exited)
    %FirmamentUploadMenu.offer_made.connect(_on_firmament_upload_menu_offer_made)

    %FirmamentDownloadMenu.exited.connect(_on_firmament_download_menu_exited)
    %FirmamentDownloadMenu.gift_chosen.connect(_on_firmament_download_menu_gift_chosen)

    %FirmamentPastUploadsMenu.exited.connect(_on_firmament_past_uploads_menu_exited)
    %FirmamentPastUploadsMenu.deletion_chosen.connect(_on_firmament_past_uploads_menu_deletion_chosen)

    %WorldEditMenu.exited.connect(_on_world_edit_menu_exited)
    %WorldEditMenu.created.connect(_on_world_edit_menu_created)
    %WorldEditMenu.saved.connect(_on_world_edit_menu_saved)

    %SettingsMenu.exited.connect(_on_settings_menu_exited)
    %SettingsMenu.saved.connect(_on_settings_menu_saved)

    Ref.player.died.connect(_on_player_death)


    randomize()
    Ref.player.disabled = true


    %GameMenu.close()
    %SaveFileMenu.close()
    %WorldEditMenu.close()
    %SettingsMenu.close()

    if not Ref.world.started_up:
        await Ref.world.start_up_done

    if RenderChecker.must_warn:
        await Ref.trans.open()
        %RenderWarning.visible = true
        Ref.splash_layer.visible = false
        await Ref.trans.close()
        await %RenderWarning.confirmed



    if Ref.shader_loader.must_compile_shaders():
        await Ref.trans.open()
        %RenderWarning.visible = false
        Ref.splash_layer.visible = false
        Ref.shader_loader.visible = true
        await Ref.trans.close()
        await Ref.shader_loader.preload_shaders()
        await Ref.trans.open()
    else:
        await Ref.trans.open()
        Ref.shader_loader.skip_shader_baking()
    Ref.shader_loader.queue_free()
    Ref.splash_layer.queue_free()
    %RenderWarning.queue_free()

    %MainMenu.open()

    Ref.audio_manager.play_song(main_menu_music, 100, 5.0)

    if get_window().has_focus():
        window_focused.emit()
    else:
        window_unfocused.emit()


    if Ref.save_file_manager.device_file.get_data("tutorial", true):
        %MainMenu.show_tutorial()
        await Ref.trans.close()
        await %MainMenu.tutorial()
        await Ref.trans.open()
        %MainMenu.hide_tutorial()
        Ref.save_file_manager.device_file.set_data("tutorial", false)
        Ref.save_file_manager.write_device_file()
        await Ref.trans.close()
        %MainMenu.activate()
    else:
        %MainMenu.hide_tutorial()
        await Ref.trans.close()
        %MainMenu.activate()

    loaded = true
    all_loaded.emit()

    print_rich("[color=#77FF77]Game ready.")


func _on_game_menu_quit_requested() -> void :
    %GameMenu.deactivate()

    await Ref.trans.open()

    Ref.audio_manager.play_song(main_menu_music, 100)

    %MainMenu.open()
    %GameMenu.close()

    await quit_game(true, true)

    await Ref.trans.close()

    %MainMenu.activate()


func _on_player_death() -> void :
    if Ref.coop_manager != null and Ref.coop_manager.is_death_override_active():
        print("[lucid-blocks-coop] Main._on_player_death intercepted for coop")
        Ref.coop_manager._on_player_died_for_coop.call_deferred()
        return
    player_death.call_deferred()


func player_death() -> void :
    if Ref.coop_manager != null and Ref.coop_manager.is_death_override_active():
        print("[lucid-blocks-coop] Main.player_death intercepted for coop")
        Ref.coop_manager._on_player_died_for_coop.call_deferred()
        return

    Steamworks.increment_statistic("death_count")
    Steamworks.set_achievement("DEATH")

    %GameMenu.deactivate()
    %DeathMenu.open()
    print("Player died.")

    Ref.audio_manager.fade_out_sfx()
    Ref.audio_manager.play_song(death_menu_music, 5)

    Ref.player.revive()
    Ref.save_file_manager.loaded_file.set_data("respawn", true)

    var first_death: bool = Ref.save_file_manager.soul_file.get_data("first_death", true)
    Ref.save_file_manager.soul_file.set_data("first_death", false)

    if Ref.sun.target_time_scale < 1.0:
        Ref.sun.set_time_scale(1.0)

    await quit_game(true, true)

    await %DeathMenu.play_cutscene(first_death)
    %DeathMenu.close()

    Ref.audio_manager.stop_song(death_menu_music)

    Ref.save_file_manager.load_file(Ref.save_file_manager.loaded_file_register)
    await enter_game(true)




func refresh() -> void :
    print("Refreshing...")

    await get_tree().process_frame
    await quit_game(true, true)
    Ref.save_file_manager.load_file(Ref.save_file_manager.loaded_file_register, false)
    await enter_game(false, false, false)









func teleport_to_dimension(new_dimension: LucidBlocksWorld.Dimension, immediate: bool = false, white_close: bool = false) -> void :
    print("Teleporting...")
    if Ref.sun.target_time_scale < 1.0:
        Ref.sun.set_time_scale(1.0)

    if not immediate:
        Ref.game_menu.deactivate()
        Ref.audio_manager.fade_out_sfx()
        Ref.player.disabled = true
        get_tree().paused = true

        await Ref.trans.open_scary()
    else:
        await get_tree().process_frame

    await quit_game(true, true)




    Ref.save_file_manager.loaded_file_register.set_data("dimension", new_dimension)


    var new_travel: bool = not Ref.save_file_manager.loaded_file_register.get_data("traveled_to_%s" % SaveFile.DIMENSION_MAP[new_dimension], false)
    Ref.save_file_manager.loaded_file_register.set_data("traveled_to_%s" % SaveFile.DIMENSION_MAP[new_dimension], true)
    Ref.save_file_manager.loaded_file_register.set_data("find_spawn", new_travel)
    var reset_world: bool = new_dimension == LucidBlocksWorld.Dimension.CHALLENGE or new_dimension == LucidBlocksWorld.Dimension.FIRMAMENT or new_dimension == LucidBlocksWorld.Dimension.YHVH
    Ref.save_file_manager.loaded_file_register.set_data("reset_world", reset_world)




    Ref.save_file_manager.write_register_file(Ref.save_file_manager.loaded_file_register)


    Ref.save_file_manager.load_file(Ref.save_file_manager.loaded_file_register, false)
    await enter_game(new_travel, new_travel, white_close)







func _on_game_menu_settings_requested() -> void :
    %GameMenu.deactivate()

    await Ref.trans.open()

    %SettingsMenu.open()
    %SettingsMenu.initialize(SettingsMenu.GAME)

    %GameMenu.state = GameMenu.SETTINGS
    %GameMenu.close()

    await Ref.trans.close()
    %SettingsMenu.activate()


func _on_main_menu_play_requested() -> void :
    %MainMenu.deactivate()

    await Ref.trans.open()

    %SaveFileMenu.open()
    %MainMenu.close()

    await Ref.trans.close()
    %SaveFileMenu.activate()


func _on_main_menu_settings_requested() -> void :
    %MainMenu.deactivate()

    await Ref.trans.open()

    %SettingsMenu.open()
    %SettingsMenu.initialize(SettingsMenu.TITLE)
    %MainMenu.close()

    await Ref.trans.close()
    %SettingsMenu.activate()


func _on_main_menu_editor_requested() -> void :
    %MainMenu.deactivate()

    await Ref.trans.open()

    Ref.save_file_manager.initialize_file()
    Ref.save_file_manager.loaded_file_register.set_data("divine", true)
    Ref.save_file_manager.load_file(Ref.save_file_manager.loaded_file_register)

    Ref.audio_manager.stop_song(main_menu_music)

    await enter_game()

    await get_tree().create_timer(1.0).timeout
    if Ref.world.decoration_to_edit_path != "":
        Ref.world.load_decoration(load(Ref.world.decoration_to_edit_path))


func _on_save_file_menu_play_requested(file: SaveFileRegister) -> void :
    %SaveFileMenu.deactivate()

    await Ref.trans.open()
    print_rich("[color=#94b09d]Starting up from save file.")
    Ref.audio_manager.stop_song(main_menu_music)

    Ref.save_file_manager.load_file(file)

    await enter_game()


func _on_save_file_menu_exited() -> void :
    %SaveFileMenu.deactivate()

    await Ref.trans.open()

    %SaveFileMenu.close()
    %MainMenu.open()

    await Ref.trans.close()
    %MainMenu.activate()


func _on_save_file_menu_edit_requested(file: SaveFileRegister) -> void :
    %SaveFileMenu.deactivate()

    await Ref.trans.open()

    Ref.save_file_manager.loaded_file_register = file

    %WorldEditMenu.initialize(file, WorldEditMenu.EDIT)
    %WorldEditMenu.open()
    %SaveFileMenu.close()

    await Ref.trans.close()
    %WorldEditMenu.activate()


func _on_save_file_menu_delete_requested(file: SaveFileRegister) -> void :
    Ref.save_file_manager.delete_save_file(file)
    %SaveFileMenu.open()


func _on_save_file_menu_new_world_requested() -> void :
    %SaveFileMenu.deactivate()

    await Ref.trans.open()

    Ref.save_file_manager.initialize_file()

    %WorldEditMenu.initialize(null, WorldEditMenu.CREATE)
    %WorldEditMenu.open()
    %SaveFileMenu.close()

    await Ref.trans.close()
    %WorldEditMenu.activate()


func _on_save_file_menu_firmament_requested() -> void :
    Ref.audio_manager.play_song(firmament_menu_music, 200, 12.0)
    %SaveFileMenu.deactivate()

    await Ref.trans.open()

    %FirmamentMenu.open()
    %SaveFileMenu.close()

    await Ref.trans.close()
    %FirmamentMenu.activate()


func _on_firmament_menu_exited() -> void :
    Ref.audio_manager.stop_song(firmament_menu_music)
    %FirmamentMenu.deactivate()

    await Ref.trans.open()

    %SaveFileMenu.open()
    %FirmamentMenu.close()

    await Ref.trans.close()
    %SaveFileMenu.activate()


func _on_firmament_menu_upload_requested() -> void :
    %FirmamentMenu.deactivate()

    await Ref.trans.open()

    %FirmamentUploadMenu.open()
    %FirmamentMenu.close()

    await Ref.trans.close()
    %FirmamentUploadMenu.activate()


func _on_firmament_past_uploads_menu_requested() -> void :
    %FirmamentMenu.deactivate()

    await Ref.trans.open()

    %FirmamentPastUploadsMenu.open()
    %FirmamentMenu.close()

    await Ref.trans.close()
    %FirmamentPastUploadsMenu.activate()

func _on_firmament_menu_download_requested() -> void :
    %FirmamentMenu.deactivate()

    await Ref.trans.open()

    %FirmamentDownloadMenu.open()
    %FirmamentMenu.close()

    await Ref.trans.close()
    %FirmamentDownloadMenu.activate()


func _on_firmament_upload_menu_exited() -> void :
    %FirmamentUploadMenu.deactivate()

    await Ref.trans.open()

    %FirmamentMenu.open()
    %FirmamentUploadMenu.close()

    await Ref.trans.close()
    %FirmamentMenu.activate()


func _on_firmament_past_uploads_menu_deletion_chosen(id: int) -> void :
    %FirmamentPastUploadsMenu.deactivate()

    await Ref.trans.open()

    %FirmamentStatusMenu.open()
    %FirmamentPastUploadsMenu.close()

    %FirmamentStatusMenu.await_result()

    await Ref.trans.close()
    %FirmamentStatusMenu.activate()

    await get_tree().create_timer(1.0, true).timeout

    var result: bool = await Steamworks.delete_workshop_qualia(id)
    if result:
        %FirmamentStatusMenu.success()
    else:
        %FirmamentStatusMenu.failure()

    await get_tree().create_timer(3.0, true).timeout

    %FirmamentStatusMenu.deactivate()

    await Ref.trans.open()

    %FirmamentStatusMenu.close()
    %FirmamentPastUploadsMenu.open()

    await Ref.trans.close()

    %FirmamentPastUploadsMenu.activate()


func _on_firmament_upload_menu_offer_made(register: SaveFileRegister) -> void :
    %FirmamentUploadMenu.deactivate()

    await Ref.trans.open()

    %FirmamentStatusMenu.open()
    %FirmamentUploadMenu.close()

    %FirmamentStatusMenu.await_result()

    await Ref.trans.close()
    %FirmamentStatusMenu.activate()

    await get_tree().create_timer(1.0, true).timeout

    var result: bool = await Steamworks.offer_save_file(register)
    if result:
        %FirmamentStatusMenu.success()
    else:
        %FirmamentStatusMenu.failure()

    await get_tree().create_timer(3.0, true).timeout

    %FirmamentStatusMenu.deactivate()

    await Ref.trans.open()

    %FirmamentStatusMenu.close()
    %FirmamentUploadMenu.open()

    await Ref.trans.close()

    %FirmamentUploadMenu.activate()


func _on_firmament_download_menu_exited() -> void :
    %FirmamentDownloadMenu.deactivate()

    await Ref.trans.open()

    %FirmamentMenu.open()
    %FirmamentDownloadMenu.close()

    await Ref.trans.close()
    %FirmamentMenu.activate()


func _on_firmament_past_uploads_menu_exited() -> void :
    %FirmamentPastUploadsMenu.deactivate()

    await Ref.trans.open()

    %FirmamentMenu.open()
    %FirmamentPastUploadsMenu.close()

    await Ref.trans.close()
    %FirmamentMenu.activate()

func _on_firmament_download_menu_gift_chosen(id: int) -> void :
    %FirmamentDownloadMenu.deactivate()

    await Ref.trans.open()

    %FirmamentStatusMenu.open()
    %FirmamentDownloadMenu.close()

    %FirmamentStatusMenu.await_result()

    await Ref.trans.close()
    %FirmamentStatusMenu.activate()

    await get_tree().create_timer(1.0, true).timeout

    var result: bool = await Steamworks.download_workshop_qualia(id)
    if result:
        %FirmamentStatusMenu.success()
    else:
        %FirmamentStatusMenu.failure()

    await get_tree().create_timer(3.0, true).timeout

    %FirmamentStatusMenu.deactivate()

    await Ref.trans.open()

    %FirmamentStatusMenu.close()
    %FirmamentDownloadMenu.open()

    await Ref.trans.close()

    %FirmamentDownloadMenu.activate()


func _on_world_edit_menu_exited() -> void :
    %WorldEditMenu.deactivate()

    await Ref.trans.open()

    %WorldEditMenu.close()
    %SaveFileMenu.open()

    await Ref.trans.close()
    %SaveFileMenu.activate()


func _on_world_edit_menu_created() -> void :
    %WorldEditMenu.deactivate()

    await Ref.trans.open()

    Ref.audio_manager.stop_song(main_menu_music)
    Ref.save_file_manager.load_file(Ref.save_file_manager.loaded_file_register)

    await new_game()

    await enter_game(true, true)


func _on_world_edit_menu_saved() -> void :
    %WorldEditMenu.deactivate()

    await Ref.trans.open()

    Ref.save_file_manager.write_register_file(Ref.save_file_manager.loaded_file_register)

    %WorldEditMenu.close()
    %SaveFileMenu.open()

    await Ref.trans.close()
    %SaveFileMenu.activate()


func _on_settings_menu_exited() -> void :
    %SettingsMenu.deactivate()

    await Ref.trans.open()

    %SettingsMenu.close()

    if %SettingsMenu.state == SettingsMenu.TITLE:
        %MainMenu.open()
    else:
        %GameMenu.open()

    await Ref.trans.close()

    if %SettingsMenu.state == SettingsMenu.TITLE:
        %MainMenu.activate()
    else:
        %GameMenu.activate()


func _on_settings_menu_saved() -> void :
    if %SettingsMenu.state == SettingsMenu.UNOPENED:
        printerr("Settings menu saved when uopened")
        return

    %SettingsMenu.deactivate()

    await Ref.trans.open()

    Ref.save_file_manager.update_settings()

    %SettingsMenu.close()

    if %SettingsMenu.state == SettingsMenu.TITLE:
        %MainMenu.open()
    else:
        %GameMenu.open()

    await Ref.trans.close()

    if %SettingsMenu.state == SettingsMenu.TITLE:
        %MainMenu.activate()
    else:
        %GameMenu.activate()


func new_game() -> void :
    if not Ref.save_file_manager.soul_file.get_data("created_qualia", false):
        await Ref.plot_manager.play_intro_cutscene()
        Ref.save_file_manager.soul_file.set_data("created_qualia", true)

    Ref.save_file_manager.loaded_file_register.set_data("traveled_to_%s" % SaveFile.DIMENSION_MAP[Ref.world.current_dimension], true)
    new_game_loaded.emit()


func enter_game(place_floor_block: bool = false, find_spawn_position: bool = false, white_close: bool = false) -> void :
    Ref.world.make_environment_changes_instant()
    Ref.environment.disable_sdfgi()

    %MainMenu.close()
    %SaveFileMenu.close()
    %WorldEditMenu.close()
    %CutsceneMenu.close()
    %GameMenu.open()

    Ref.world.select_generator()


    find_spawn_position = find_spawn_position or Ref.save_file_manager.loaded_file_register.get_data("find_spawn", false)
    Ref.save_file_manager.loaded_file_register.set_data("find_spawn", false)

    var respawn: bool = Ref.save_file_manager.loaded_file.get_data("respawn", false)
    if respawn:
        if len(Ref.world.respawn_positions) == 0 or Ref.player.wandering_spirit:
            find_spawn_position = true
        else:
            var closest_position: Vector3i = Ref.world.respawn_positions.keys()[0]
            for position in Ref.world.respawn_positions:
                if position.distance_to(Ref.player.global_position) < closest_position.distance_to(Ref.player.global_position):
                    closest_position = position
            Ref.player.global_position = Vector3(closest_position) + Vector3(0.5, 0.0, 0.5)
        Ref.save_file_manager.loaded_file.set_data("respawn", false)

    print_rich("[color=#94b09d]Loading preserved nodes...")


    Ref.preserve_node_manager.enter_game()
    await get_tree().process_frame

    print_rich("[color=#94b09d]Preserved nodes loaded.")

    print_rich("[color=#94b09d]Initializing world...")
    Ref.world.initialize()

    print_rich("[color=#94b09d]World initialized.")

    if find_spawn_position:
        await Ref.world.spawn_tester.find_spawn_position(Ref.player.global_position if Ref.player.wandering_spirit else Vector3(), Ref.world.current_dimension, 3.0 if Ref.player.wandering_spirit else 1.0)

    print_rich("[color=#94b09d]Loading world chunks...")

    Ref.world.load_enabled = true

    if not Ref.world.is_all_loaded():
        await Ref.world.all_loaded
    await get_tree().process_frame


    if upside_down and place_floor_block:
        var safety_position: Vector3 = Ref.player.global_position + Vector3(0, 3, 0)
        if Ref.world.is_position_loaded(safety_position) and not Ref.world.is_block_solid_at(safety_position):
            Ref.world.place_block_at(safety_position, upside_down_block, false, true)
        Ref.player.global_position += Vector3(0, 2, 0)
    print_rich("[color=#94b09d]World chunks loaded")

    Ref.entity_spawner.start_spawning()

    Ref.preserve_node_manager.enable_all_nodes()
    Ref.boss_manager.enable_boss()

    print_rich("[color=#94b09d]All nodes enabled.")


    Ref.player.initialize()
    if respawn:
        Ref.player.make_invincible_temporary()
    else:
        Ref.player.remove_temporary_invincible()

    Ref.player.disabled = false

    print_rich("[color=#94b09d]Player initialized.")


    Ref.world.simulate_enabled = true

    print_rich("[color=#94b09d]Water/fire simulations turned on.")

    world_loaded.emit()
    Ref.environment.enable_sdfgi()

    print_rich("[color=#94b09d]Done!")

    Ref.player.consume_actions()

    if white_close:
        await Ref.trans.close_fade()
    else:
        await Ref.trans.close()

    Ref.world.make_environment_changes_normal.call_deferred()
    %GameMenu.activate()

    Ref.audio_manager.fade_in_sfx()

    game_playable.emit()

    Steamworks.set_achievement("NEW_WORLD", true)


func quit_game(save_game: bool, write_file: bool) -> void :
    if Ref.coop_manager != null \
        and Ref.coop_manager.is_death_override_active() \
        and is_instance_valid(Ref.player) \
        and Ref.player.health <= 0:
        print("[lucid-blocks-coop] Main.quit_game ignored during coop respawn")
        Ref.coop_manager._on_player_died_for_coop.call_deferred()
        return

    if write_file:
        Ref.save_notifier.notify()

    print("Quitting game...")
    game_quit.emit()

    get_tree().paused = true
    Ref.player.disabled = true

    Ref.entity_spawner.stop_spawning()

    Ref.audio_manager.fade_out_sfx()

    Ref.world.simulate_enabled = false
    print("Load enabled: ", Ref.world.load_enabled)
    if not Ref.world.is_all_loaded():
        print("Must finish loading world first...")
        Ref.world.debug_stall = true
        await Ref.world.all_loaded
        Ref.world.debug_stall = false
    print("Quit frame 1...")
    await get_tree().process_frame
    Ref.world.load_enabled = false

    if save_game:
        print("Saving file...")
        await Ref.save_file_manager.save_file(write_file)
        print("File saved.")


    Ref.preserve_node_manager.exit_game.call_deferred()
    Ref.boss_manager.exit_game.call_deferred()
    Ref.sun.exit_game()
    await get_tree().process_frame
    print("Quit frame 2...")


    for node in get_tree().get_nodes_in_group("delete_on_quit"):
        if is_instance_valid(node):
            node.queue_free.call_deferred()
    await get_tree().process_frame
    print("Quit frame 3...")

    Ref.world.clear()
    await get_tree().process_frame
    print("Quit frame 4...")

func start_challenge() -> void :
    in_challenge = true


func end_challenge(success: bool) -> void :
    if success:
        Steamworks.set_achievement("CHALLENGE")
    in_challenge = false


func start_ending() -> void :
    in_ending = true


func end_ending(success: bool) -> void :
    in_ending = false
    if success:
        Ref.plot_manager.god_killed = true
        Steamworks.set_achievement("END_GAME")


func save_file_register(register: SaveFileRegister) -> void :
    register.set_data("in_challenge", in_challenge)
    register.set_data("in_ending", in_ending)


func load_file_register(register: SaveFileRegister) -> void :
    creative = register.get_data("divine", false)
    wrathful_torus = register.get_data("wrath", false)
    progression_disabled = register.get_data("progression_disabled", false)
    upside_down = register.get_data("upside_down", false)
    in_challenge = register.get_data("in_challenge", false)
    in_ending = register.get_data("in_ending", false)


func _notification(what: int) -> void :
    match what:
        MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
            print("Window focus out")
            window_unfocused.emit()
        MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN:
            print("Window focus in")
            window_focused.emit()
