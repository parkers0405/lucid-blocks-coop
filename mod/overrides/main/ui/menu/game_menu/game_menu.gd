class_name GameMenu extends Menu


enum {DEFAULT, INVENTORY_NORMAL, INVENTORY_CACHE_CUBE, INVENTORY_CRUCIBLE, PAUSE, SETTINGS, RENAMING, LEVELING_UP}
enum {STYLE_CACHE_CUBE, STYLE_CABINET, STYLE_HOPPER}

signal settings_requested
signal quit_requested
signal inventory_closed
signal inventory_opened
signal rename_complete(new_name: String, cancelled: bool)

var state: int = DEFAULT
var inventory_screen: int = 0
var ui_tree_pause_requested: bool = false

var debug_visible: bool = false:
    set(val):
        debug_visible = val
        if is_inside_tree():
            %DebugContainer.visible = debug_visible
var hud_visible: bool = true:
    set(val):
        hud_visible = val
        %BottomContainer.modulate.a = 1.0 if hud_visible else 0.0
        %Crosshair.modulate.a = 1.0 if hud_visible else 0.0
var fullscreen: bool = false:
    set(val):
        fullscreen = val
        if not fullscreen:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
        else:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _ready() -> void :
    Ref.main.world_loaded.connect(_on_world_loaded)
    Ref.player.held_item_index_changed.connect(_on_held_item_index_changed)

    %TrashInventoryWidget.initialize(%TrashInventory)

    %TitleContainer.title_index_changed.connect(_on_title_index_changed)

    %QuitButton.pressed.connect(_on_quit_pressed)
    %SettingsButton.pressed.connect(emit_signal.bind("settings_requested"))
    %ResumeButton.pressed.connect(_on_resume_pressed)

    %NamePanel.cancelled.connect(_on_rename_cancelled)
    %NamePanel.confirmed.connect(_on_rename_confirmed)
    %NamePanel.cleared.connect(_on_rename_cleared)

    %CreativeScreen.tab_changed.connect(_on_tab_changed)

    %TitleContainer.override_index(0)
    close()


func _should_pause_tree_for_ui() -> bool:
    return not (Ref.coop_manager != null and Ref.coop_manager.has_active_session())


func _begin_tree_pause_for_ui() -> void:
    ui_tree_pause_requested = _should_pause_tree_for_ui()
    if ui_tree_pause_requested:
        get_tree().paused = true


func _end_tree_pause_for_ui(force_unpause: bool = false) -> void:
    if force_unpause or ui_tree_pause_requested:
        get_tree().paused = false
    ui_tree_pause_requested = false


func _on_resume_pressed() -> void :
    close_pause()


func _on_quit_pressed() -> void :
    _end_tree_pause_for_ui(true)
    if Ref.coop_manager != null:
        await Ref.coop_manager.prepare_for_menu_quit()
    if Ref.world != null and not Ref.world.load_enabled:
        Ref.world.load_enabled = true
    if Ref.world != null and not Ref.world.is_all_loaded():
        await Ref.world.all_loaded
        await get_tree().process_frame
    emit_signal("quit_requested")


func _on_title_index_changed(index: int) -> void :
    update_inventory_screen(index)


func _on_world_loaded() -> void :
    %TitleContainer.renew_index()


func _on_tab_changed(_tab: int) -> void :
    %SoundBoard.play_select_sound()


func _on_held_item_index_changed() -> void :
    %HotbarOutline.position.x = 21 * Ref.player.held_item_index

    if state == DEFAULT:
        %HeldItemPopup.linger(Ref.player_hotbar.items[Ref.player.held_item_index])


func _unhandled_input(event: InputEvent) -> void :
    if event.is_action_pressed("fullscreen"):
        fullscreen = not fullscreen
        save_ui_preferences()


func _input(event: InputEvent) -> void :
    if not active or state == RENAMING or state == LEVELING_UP:
        return

    if state == INVENTORY_NORMAL:
        if event.is_action_pressed("menu_left"):
            %TitleContainer._on_left_pressed()
            %SoundBoard.play_select_sound()
        if event.is_action_pressed("menu_right"):
            %TitleContainer._on_right_pressed()
            %SoundBoard.play_select_sound()

    if state == DEFAULT and event.is_action_pressed("inventory", false):
        open_inventory(INVENTORY_NORMAL)
    elif is_inventory_open() and event.is_action_pressed("inventory", false):
        close_inventory.call_deferred()
    if is_inventory_open() and event.is_action_pressed("drop_item", false):
        if InventorySlot.held_item != null:
            Ref.player.get_node("%DropItems").drop_item(InventorySlot.held_item.item)
            InventorySlot.held_item.queue_free()
            InventorySlot.held_item = null
            InventorySlot.state = DEFAULT
        elif InventorySlot.hovered_slot != null and not InventorySlot.hovered_slot.infinite:
            Ref.player.get_node("%DropItems").drop_and_remove_from_inventory(InventorySlot.hovered_slot.get_parent().inventory, InventorySlot.hovered_slot.index)

    if state == DEFAULT and event.is_action_pressed("pause", false):
        open_pause()
    elif is_inventory_open() and (event.is_action_pressed("pause", false) or event.is_action_pressed("back", false)):
        close_inventory()
    elif state == PAUSE and (event.is_action_pressed("pause", false) or event.is_action_pressed("back", false)):
        close_pause()

    if Input.is_action_just_pressed("toggle_debug"):
        debug_visible = not debug_visible
        save_ui_preferences()
    if state == DEFAULT and Input.is_action_just_pressed("toggle_hud"):
        hud_visible = not hud_visible
        save_ui_preferences()


func update_inventory_screen(index: int) -> void :
    var update_tome: bool = index == 3 and inventory_screen != 3

    if inventory_screen == 3 and index != 3:
        %TomeScreen.force_exit()

    inventory_screen = index

    %FusionScreen.visible = inventory_screen == 0 and not Ref.main.creative
    %CreativeScreen.visible = inventory_screen == 0 and Ref.main.creative
    %EquipmentScreen.visible = inventory_screen == 1
    %MusicScreen.visible = inventory_screen == 2 and Ref.main.creative
    %RosaryScreen.visible = inventory_screen == 2 and not Ref.main.creative
    %TomeScreen.visible = inventory_screen == 3

    if update_tome:
        %TomeScreen.update()

    if %CreativeScreen.visible:
        %CreativeScreen.open()


func is_inventory_open() -> bool:
    return state == INVENTORY_CACHE_CUBE or state == INVENTORY_NORMAL or state == INVENTORY_CRUCIBLE


func initialize_cache_cube_inventory(inventory: Inventory) -> void :
    %CacheCubeInventory.initialize(inventory)


func open_pause() -> void :
    _begin_tree_pause_for_ui()
    state = PAUSE

    %HUDContainer.visible = false
    %PauseContainer.visible = true
    %Cover.visible = true

    Ref.player.movement_enabled = false
    Ref.player.can_switch_hotbar = false
    MouseHandler.release()


func close_pause() -> void :
    if state == PAUSE:
        Ref.player.consume_actions()

    _end_tree_pause_for_ui()
    state = DEFAULT

    %HUDContainer.visible = true
    %PauseContainer.visible = false
    %Cover.visible = false
    Ref.player.movement_enabled = true
    Ref.player.can_switch_hotbar = true
    MouseHandler.capture()


func open_inventory(new_state: int, style: int = STYLE_CACHE_CUBE) -> void :
    %BottomContainer.modulate.a = 1.0

    %RosaryScreen.update()
    %TomeScreen.update()

    if new_state == INVENTORY_NORMAL:
        %FusionScreen.initialize()
        %EquipmentScreen.initialize()
    %Inventory.initialize(Ref.player_inventory)

    state = new_state

    %AdvancedFusionScreen.visible = state == INVENTORY_CRUCIBLE
    %CacheCubeContainer.visible = state == INVENTORY_CACHE_CUBE
    %CacheCubeContainer.stylize(style)
    %PlayerContainer.visible = state == INVENTORY_NORMAL

    %HiddenContainer.visible = true
    %Cover.visible = true
    %HotbarOutline.visible = false
    %HeldItemPopup.exit()
    %Crosshair.visible = false

    Ref.player.movement_enabled = false
    Ref.player.can_switch_hotbar = false

    MouseHandler.release()

    %FusionScreen.start_processing()

    inventory_opened.emit()


func close_inventory(hog_mouse: bool = true) -> void :
    if state == INVENTORY_NORMAL and inventory_screen == 3:
        %TomeScreen.force_exit()

    if InventorySlot.hovered_slot != null:
        InventorySlot.hovered_slot._on_mouse_exited()

    if InventorySlot.state == InventorySlot.HOLDING_ITEM:
        var held_item: ItemState = InventorySlot.held_item.item
        InventorySlot.held_item.queue_free()

        var remaining_item: ItemState = Ref.player_hotbar.accept(held_item)
        if remaining_item != null:
            remaining_item = Ref.player_inventory.accept(remaining_item)
        if remaining_item != null:
            Ref.player.get_node("%DropItems").drop_item(remaining_item)

        InventorySlot.state = InventorySlot.IDLE
        InventorySlot.held_item = null

    %FusionScreen.stop_processing()

    clear_fusion_slots()

    %PlayerHotbar.initialize(Ref.player_hotbar)

    if state != DEFAULT:
        Ref.player.consume_actions()
    state = DEFAULT

    %Crosshair.visible = true
    %Inventory.reset()
    %CacheCubeInventory.reset()
    %HiddenContainer.visible = false
    %Cover.visible = false

    %HotbarOutline.visible = true

    Ref.player.movement_enabled = true
    Ref.player.can_switch_hotbar = true

    if hog_mouse:
        MouseHandler.capture()

    inventory_closed.emit()
    hud_visible = hud_visible


func clear_fusion_slots() -> void :
    for inventory in [Ref.player_fusion_source, Ref.player_fusion_result]:
        for i in range(len(inventory.items)):
            var item_state: ItemState = inventory.items[i]
            if item_state == null:
                continue
            inventory.set_item(i, null)
            var remaining_item: ItemState = Ref.player_inventory.accept(item_state)
            if remaining_item != null:
                remaining_item = Ref.player_hotbar.accept(remaining_item)
            if remaining_item != null:
                Ref.player.get_node("%DropItems").drop_item(remaining_item)


func open() -> void :
    visible = true
    if not state == SETTINGS:
        %PlayerHotbar.initialize(Ref.player_hotbar)
        _end_tree_pause_for_ui(true)
        close_pause()
        close_inventory()
        %TomeScreen.update()
    else:
        state = PAUSE


func close() -> void :
    visible = false
    MouseHandler.release()


func request_entity_name(current_name: String) -> void :
    _begin_tree_pause_for_ui()

    state = RENAMING
    MouseHandler.release()

    %Cover.visible = true
    %HUDContainer.visible = false
    %NamePanel.initialize(current_name)
    %NamePanel.open()

    Ref.player.movement_enabled = false
    Ref.player.can_switch_hotbar = false


func close_renaming_panel() -> void :
    %Cover.visible = false
    %HUDContainer.visible = true
    %NamePanel.close()
    if state == RENAMING:
        Ref.player.consume_actions()
    Ref.player.movement_enabled = true
    Ref.player.can_switch_hotbar = true

    MouseHandler.capture()

    state = DEFAULT
    _end_tree_pause_for_ui()


func _on_rename_cancelled() -> void :
    rename_complete.emit("", true)
    close_renaming_panel()


func _on_rename_confirmed(new_name: String) -> void :
    rename_complete.emit(new_name, false)
    close_renaming_panel()


func _on_rename_cleared() -> void :
    rename_complete.emit("", false)
    close_renaming_panel()


func load_ui_preferences() -> void :
    hud_visible = Ref.save_file_manager.device_file.get_data("hud_visible", true)
    debug_visible = Ref.save_file_manager.device_file.get_data("debug_visible", false)
    fullscreen = Ref.save_file_manager.device_file.get_data("fullscreen", false)


func save_ui_preferences() -> void :
    Ref.save_file_manager.device_file.set_data("hud_visible", hud_visible)
    Ref.save_file_manager.device_file.set_data("debug_visible", debug_visible)
    Ref.save_file_manager.device_file.set_data("fullscreen", fullscreen)
