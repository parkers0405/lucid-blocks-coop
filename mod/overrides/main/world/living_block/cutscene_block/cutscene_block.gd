class_name CutsceneBlock extends LivingBlock

@export var tiamana_yield: float = 0.5

var used_up: bool = false
var playing_cutscene: bool = false
var cutscene_instance: Cutscene


func _ready() -> void:
    Ref.save_file_manager.settings_updated.connect(_on_settings_updated)
    _on_settings_updated()

    if Ref.main.progression_disabled:
        %GlitchParticles.emitting = false
        %Sphere.visible = false
        %Light.visible = false


func _on_settings_updated() -> void:
    var shadow_quality: int = Ref.save_file_manager.settings_file.get_data("shadow_quality", 2)
    var light: OmniLight3D = %Light
    if shadow_quality == 0:
        light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
    else:
        light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE


func interact(interactor: Entity) -> void:
    if not can_currently_interact(interactor):
        return
    super.interact(interactor)

    used_up = true
    Steamworks.set_achievement("CUTSCENE")

    Ref.game_menu.deactivate()
    Ref.player.disabled = true
    get_tree().paused = true
    Ref.audio_manager.fade_out_sfx()

    if Ref.world.current_dimension == LucidBlocksWorld.Dimension.CHALLENGE:
        print("Challenge end win!")
        await Ref.trans.open_scary(1.0)
        await stall_world()

        Ref.main.end_challenge(true)

        var first_bead: bool = Ref.save_file_manager.soul_file.get_data("first_bead", true)

        prepare_cutscene_screen()
        await bead_cutscene(first_bead)
        clear_cutscene_screen()

        Ref.plot_manager.give_bead()
        Ref.save_file_manager.soul_file.set_data("first_bead", false)
        Ref.plot_manager.mark_cutscene_as_watched()
        Ref.plot_manager.remove_cutscene()

        give_tiamana()

        Ref.world.break_block_at(position, false, true)
        if Ref.coop_manager != null:
            await Ref.coop_manager._travel_group_to_dimension_async(int(LucidBlocksWorld.Dimension.NARAKA), true, false)
        else:
            await Ref.main.teleport_to_dimension(LucidBlocksWorld.Dimension.NARAKA, true)
    else:
        Ref.plot_manager.mark_block_as_collected(Vector3i(global_position))

        cutscene_instance = Ref.plot_manager.serve_cutscene()

        if cutscene_instance is EndingCutscene:
            print("Ending cutscene...")
            await Ref.trans.open_scary(5.0)
            await stall_world()

            Ref.cutscene_menu.add_cutscene(cutscene_instance)

            await Ref.plot_manager.play_pre_ending_cutscene()

            Ref.main.start_ending()
            cutscene_instance.queue_free()
            Ref.world.break_block_at(position, false, true)
            if Ref.coop_manager != null:
                await Ref.coop_manager._travel_group_to_dimension_async(int(LucidBlocksWorld.Dimension.YHVH), true, true)
            else:
                await Ref.main.teleport_to_dimension(LucidBlocksWorld.Dimension.YHVH, true, true)
        elif cutscene_instance is ChallengeCutscene:
            print("Challenge cutscene...")
            await Ref.trans.open_scary(0.0)
            await stall_world()

            Ref.cutscene_menu.add_cutscene(cutscene_instance)

            Ref.main.start_challenge()
            cutscene_instance.queue_free()
            Ref.world.break_block_at(position, false, true)
            if Ref.coop_manager != null:
                await Ref.coop_manager._travel_group_to_dimension_async(int(LucidBlocksWorld.Dimension.CHALLENGE), true, false)
            else:
                await Ref.main.teleport_to_dimension(LucidBlocksWorld.Dimension.CHALLENGE, true)
        else:
            print("Regular cutscene...")
            await Ref.trans.open_scary(5.0)
            Ref.cutscene_menu.add_cutscene(cutscene_instance)

            await open_cutscene()
            await cutscene_instance.play_wrapper()

            var first_bead: bool = Ref.save_file_manager.soul_file.get_data("first_bead", true)
            var bead_given: bool = Ref.plot_manager.bead_eligible
            if bead_given:
                Ref.plot_manager.give_bead()
                Ref.save_file_manager.soul_file.set_data("first_bead", false)
            Ref.plot_manager.mark_cutscene_as_watched()
            Ref.plot_manager.remove_cutscene()
            give_tiamana()

            await close_cutscene(bead_given, first_bead)


func open_cutscene() -> void:
    if playing_cutscene:
        return
    playing_cutscene = true

    prepare_cutscene_screen()

    Ref.game_menu.close()
    Ref.cutscene_menu.open()

    await Ref.trans.close()


func close_cutscene(show_bead: bool, first_bead: bool) -> void:
    if not playing_cutscene:
        printerr("Closing a cutscene that isn't playing")
        return

    await Ref.trans.open()

    Ref.cutscene_menu.close()
    cutscene_instance.queue_free()

    if show_bead:
        await bead_cutscene(first_bead)

    clear_cutscene_screen()

    Ref.world.break_block_at(position, false, true)
    await Ref.main.refresh()

    playing_cutscene = false


func can_currently_interact(interactor: Entity) -> bool:
    return (
        super.can_currently_interact(interactor)
        and not used_up
        and interactor == Ref.player
        and not Ref.main.progression_disabled
        and (Ref.world.current_dimension == LucidBlocksWorld.Dimension.NARAKA or Ref.world.current_dimension == LucidBlocksWorld.Dimension.CHALLENGE)
    )


func bead_cutscene(first_bead: bool) -> void:
    Ref.bead_get_menu.activate()
    Ref.bead_get_menu.open()
    await Ref.trans.close()
    await Ref.bead_get_menu.play_cutscene(first_bead)
    Ref.bead_get_menu.deactivate()
    Ref.bead_get_menu.close()


func prepare_cutscene_screen() -> void:
    Ref.dither_filter.visible = true
    Ref.water_filter.modulate.a = 0.0


func clear_cutscene_screen() -> void:
    Ref.dither_filter._on_settings_updated()
    Ref.water_filter.modulate.a = 1.0


func give_tiamana() -> void:
    if Ref.plot_manager.debug_disable_tiamana_gain_from_cutscene and Ref.main.debug:
        return
    Ref.player.get_node("%Level").give_tiamana(tiamana_yield, Level.TiamanaSource.CUTSCENE)


func stall_world() -> void:
    print("Pre-stall load enabled: ", Ref.world.load_enabled)
    if not Ref.world.is_all_loaded():
        print("Must finish loading world first (cutscene block)...")
        Ref.world.debug_stall = true
        await Ref.world.all_loaded
        Ref.world.debug_stall = false
