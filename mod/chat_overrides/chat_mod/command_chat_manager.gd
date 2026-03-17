extends Node

const MAX_HISTORY_MESSAGES: int = 100
const MAX_COMMAND_HISTORY: int = 50
const MAX_VISIBLE_OPEN_MESSAGES: int = 8
const MAX_VISIBLE_CLOSED_MESSAGES: int = 4
const MAX_VISIBLE_SUGGESTIONS: int = 6
const CLOSED_MESSAGE_LIFETIME_SEC: float = 12.0
const MAX_HISTORY_MESSAGE_CHARS: int = 256
const CHAT_WIDTH: float = 240.0
const COMMAND_COLOR: String = "d7e3ff"
const SYSTEM_COLOR: String = "f3efe2"
const ERROR_COLOR: String = "ff9b91"
const HINT_COLOR: String = "a9b7d0"
const CHAT_COLOR: String = "ffffff"

var hud: CanvasLayer
var chat_margin: MarginContainer
var chat_stack: VBoxContainer
var history_panel: PanelContainer
var history_scroll: ScrollContainer
var history_label: RichTextLabel
var suggestion_panel: PanelContainer
var suggestion_title_label: Label
var suggestion_scroll: ScrollContainer
var suggestion_list: VBoxContainer
var suggestion_hint_label: Label
var input_panel: PanelContainer
var input: LineEdit
var ghost_label: RichTextLabel
var previous_game_menu_active: bool = true

var restore_capture_on_close: bool = false
var suppress_input_change: bool = false
var history_messages: Array[Dictionary] = []
var command_history: PackedStringArray = PackedStringArray()
var command_history_index: int = -1
var draft_input: String = ""
var last_status_message: String = ""
var active_suggestions: Array = []
var selected_suggestion_index: int = -1

var COMMAND_REGISTRY: Dictionary = {
    "/help": {"desc": "Show list of commands", "args": []},
    "/tp": {"desc": "Teleport to player or coordinates", "args": ["<target>", "[destination]"]},
    "/gamemode": {"desc": "Change player game mode", "args": ["<creative|survival|spectator>"]},
    "/spawn": {"desc": "Spawn an entity at your location", "args": ["<entity>", "[count]"]},
    "/spawnlist": {"desc": "List all spawnable entities", "args": []},
    "/spawnmenu": {"desc": "Open the mob spawn browser", "args": []},
    "/avatar": {"desc": "Change your player avatar", "args": ["<id>"]},
    "/host": {"desc": "Host a multiplayer server", "args": ["[port]"]},
    "/join": {"desc": "Join a multiplayer server", "args": ["<ip>", "[port]"]},
    "/pocket": {"desc": "Travel to a pocket dimension", "args": []},
    "/visit": {"desc": "Visit a player's pocket dimension", "args": []}
}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_process(true)
    _build_ui()
    if get_viewport() != null and not get_viewport().size_changed.is_connected(_refresh_chat_layout):
        get_viewport().size_changed.connect(_refresh_chat_layout)
    call_deferred("_refresh_chat_layout")
    _capture_coop_status_message(true)

func is_command_chat_open() -> bool:
    return _is_open()

func _process(_delta: float) -> void:
    _refresh_chat_layout()
    _capture_coop_status_message()
    _refresh_chat_visibility()

func _input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    if not event.pressed or event.echo:
        return

    if _is_open():
        match event.keycode:
            KEY_ESCAPE:
                _close_chat(true)
                get_viewport().set_input_as_handled()
            KEY_TAB:
                _cycle_suggestion(-1 if event.shift_pressed else 1)
                get_viewport().set_input_as_handled()
            KEY_UP:
                _step_command_history(-1)
                get_viewport().set_input_as_handled()
            KEY_DOWN:
                _step_command_history(1)
                get_viewport().set_input_as_handled()
        return

    if not _can_open_chat():
        return

    if event.unicode == 47 or event.keycode == KEY_SLASH:
        _open_chat("/")
        get_viewport().set_input_as_handled()
    elif event.keycode == KEY_T or event.keycode == KEY_ENTER:
        _open_chat("")
        get_viewport().set_input_as_handled()

func _build_ui() -> void:
    hud = CanvasLayer.new()
    hud.layer = 70
    add_child(hud)

    chat_margin = MarginContainer.new()
    chat_margin.visible = false
    chat_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    chat_margin.anchor_left = 0.0
    chat_margin.anchor_top = 1.0
    chat_margin.anchor_right = 0.0
    chat_margin.anchor_bottom = 1.0
    hud.add_child(chat_margin)

    chat_stack = VBoxContainer.new()
    chat_stack.alignment = BoxContainer.ALIGNMENT_END
    chat_stack.add_theme_constant_override("separation", 2)
    chat_margin.add_child(chat_stack)

    history_panel = PanelContainer.new()
    history_panel.visible = false
    history_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    history_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var history_bg := StyleBoxFlat.new()
    history_bg.bg_color = Color(0, 0, 0, 1)
    history_bg.corner_radius_top_left = 2
    history_bg.corner_radius_top_right = 2
    history_bg.corner_radius_bottom_left = 2
    history_bg.corner_radius_bottom_right = 2
    history_panel.add_theme_stylebox_override("panel", history_bg)
    history_panel.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
    chat_stack.add_child(history_panel)

    var history_margin := MarginContainer.new()
    history_margin.add_theme_constant_override("margin_left", 4)
    history_margin.add_theme_constant_override("margin_right", 4)
    history_margin.add_theme_constant_override("margin_top", 4)
    history_margin.add_theme_constant_override("margin_bottom", 4)
    history_panel.add_child(history_margin)

    history_scroll = ScrollContainer.new()
    history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    history_scroll.follow_focus = true
    history_margin.add_child(history_scroll)

    history_label = RichTextLabel.new()
    history_label.bbcode_enabled = true
    history_label.fit_content = false
    history_label.scroll_active = false
    history_label.scroll_following = true
    history_label.selection_enabled = false
    history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    history_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    history_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    history_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    history_label.add_theme_font_size_override("normal_font_size", 7)
    history_label.add_theme_color_override("default_color", Color(1, 1, 1))
    history_label.add_theme_color_override("font_shadow_color", Color(0.2, 0.2, 0.2, 1.0))
    history_label.add_theme_constant_override("shadow_offset_x", 1)
    history_label.add_theme_constant_override("shadow_offset_y", 1)
    history_label.add_theme_constant_override("shadow_outline_size", 1)
    history_scroll.add_child(history_label)


    input_panel = PanelContainer.new()
    input_panel.visible = false
    input_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var input_bg := StyleBoxFlat.new()
    input_bg.bg_color = Color(0, 0, 0, 1)
    input_bg.corner_radius_top_left = 2
    input_bg.corner_radius_top_right = 2
    input_bg.corner_radius_bottom_left = 2
    input_bg.corner_radius_bottom_right = 2
    input_panel.add_theme_stylebox_override("panel", input_bg)
    input_panel.self_modulate = Color(1.0, 1.0, 1.0, 0.45)
    input_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    chat_stack.add_child(input_panel)

    var input_margin := MarginContainer.new()
    input_margin.add_theme_constant_override("margin_left", 6)
    input_margin.add_theme_constant_override("margin_right", 6)
    input_margin.add_theme_constant_override("margin_top", 4)
    input_margin.add_theme_constant_override("margin_bottom", 4)
    input_panel.add_child(input_margin)

    var input_overlay = MarginContainer.new()
    input_margin.add_child(input_overlay)
    
    ghost_label = RichTextLabel.new()
    ghost_label.bbcode_enabled = true
    ghost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ghost_label.scroll_active = false
    ghost_label.autowrap_mode = TextServer.AUTOWRAP_OFF
    ghost_label.add_theme_font_size_override("normal_font_size", 7)
    
    var ghost_margin = MarginContainer.new()
    ghost_margin.add_theme_constant_override("margin_top", 2)
    ghost_margin.add_theme_constant_override("margin_left", 0)
    ghost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ghost_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    ghost_margin.add_child(ghost_label)
    input_overlay.add_child(ghost_margin)

    input = LineEdit.new()
    var input_style := StyleBoxEmpty.new()
    input.add_theme_stylebox_override("normal", input_style)
    input.add_theme_stylebox_override("focus", input_style)
    input.add_theme_color_override("font_color", Color(1, 1, 1, 1))
    input.placeholder_text = ""
    input.clear_button_enabled = false
    input.add_theme_font_size_override("font_size", 7)
    input.text_changed.connect(_on_input_text_changed)
    input.text_submitted.connect(_on_text_submitted)
    
    var input_inner_margin = MarginContainer.new()
    input_inner_margin.add_theme_constant_override("margin_top", 2)
    input_inner_margin.add_theme_constant_override("margin_left", 0)
    input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    input_inner_margin.add_child(input)
    input_overlay.add_child(input_inner_margin)

func _refresh_chat_layout() -> void:
    if get_viewport() == null or chat_margin == null or history_label == null or input == null:
        return

    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var chat_width: float = minf(CHAT_WIDTH, maxf(120.0, viewport_size.x * 0.70))
    var target_height: float = 0.0
    if _is_open():
        target_height = 120.0
    else:
        var passive_count: int = mini(MAX_VISIBLE_CLOSED_MESSAGES, _get_visible_messages().size())
        target_height = 4.0 + passive_count * 9.0 if passive_count > 0 else 0.0
    var chat_height: float = minf(target_height, maxf(76.0, viewport_size.y - 20.0))
    
    chat_margin.offset_left = 4.0
    chat_margin.offset_right = 4.0 + chat_width
    chat_margin.offset_bottom = -36.0
    chat_margin.offset_top = -36.0 - chat_height

    history_label.custom_minimum_size.x = maxf(120.0, chat_width - 16.0)
    input.custom_minimum_size = Vector2(maxf(120.0, chat_width - 12.0), 16.0)
    if ghost_label:
        ghost_label.custom_minimum_size = Vector2(maxf(120.0, chat_width - 12.0), 16.0)

    var input_height: float = 16.0 if _is_open() else 0.0
    var suggestion_height: float = 0.0
    var history_height: float = maxf(9.0 if _is_open() else 6.0, chat_height - input_height - 4.0)
    if history_scroll != null:
        history_scroll.custom_minimum_size = Vector2(maxf(120.0, chat_width - 16.0), history_height)
        history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _can_open_chat() -> bool:
    return is_instance_valid(Ref.main) \
        and is_instance_valid(Ref.world) \
        and Ref.main.loaded \
        and Ref.world.load_enabled \
        and get_viewport().gui_get_focus_owner() == null

func _is_open() -> bool:
    return input_panel != null and input_panel.visible

func _open_chat(initial_text: String = "") -> void:
    if not _can_open_chat() or input == null:
        return

    restore_capture_on_close = MouseHandler.captured
    MouseHandler.release()
    if is_instance_valid(Ref.player):
        Ref.player.consume_actions()
    if is_instance_valid(Ref.game_menu):
        previous_game_menu_active = Ref.game_menu.active
        Ref.game_menu.active = false
    chat_margin.visible = true
    input_panel.visible = true
    input.editable = true
    command_history_index = -1
    _set_input_text(initial_text, false)
    draft_input = input.text
    input.grab_focus()
    input.caret_column = input.text.length()
    _refresh_suggestions()
    _refresh_chat_visibility()

func _close_chat(restore_capture: bool = true) -> void:
    if input == null:
        return

    input_panel.visible = false
    _set_input_text("", false)
    command_history_index = -1
    draft_input = ""
    selected_suggestion_index = -1
    active_suggestions.clear()
    get_viewport().gui_release_focus()
    if is_instance_valid(Ref.game_menu):
        Ref.game_menu.active = previous_game_menu_active
    if is_instance_valid(Ref.player):
        Ref.player.consume_actions()
    if restore_capture and restore_capture_on_close:
        MouseHandler.capture()
    restore_capture_on_close = false
    _refresh_chat_visibility()

func _on_input_text_changed(new_text: String) -> void:
    if suppress_input_change:
        return
    if command_history_index == -1:
        draft_input = new_text
    _refresh_suggestions()

func _on_text_submitted(raw_text: String) -> void:
    var text: String = raw_text.strip_edges()
    _close_chat(true)
    
    if text == "":
        return

    _record_command_history(text)

    if text.begins_with("/"):
        _push_history(text, COMMAND_COLOR)
        if Ref.coop_manager != null and Ref.coop_manager.has_method("execute_command"):
            Ref.coop_manager.execute_command(text)
        else:
            _push_history("Commands are unavailable right now.", ERROR_COLOR)
    else:
        if Ref.coop_manager != null and Ref.coop_manager.has_method("send_chat_message"):
            Ref.coop_manager.send_chat_message(text)
        else:
            _push_history("<You> " + text, CHAT_COLOR)

func receive_chat_message(player_name: String, message: String) -> void:
    _push_history("<" + player_name + "> " + message, CHAT_COLOR)

func display_system_message(message: String, color: String = SYSTEM_COLOR) -> void:
    _push_history(message, color)

func _record_command_history(text: String) -> void:
    if text == "":
        return
    if command_history.is_empty() or command_history[command_history.size() - 1] != text:
        command_history.append(text)
    while command_history.size() > MAX_COMMAND_HISTORY:
        command_history.remove_at(0)

func _step_command_history(direction: int) -> void:
    if input == null or command_history.is_empty():
        return

    if command_history_index == -1:
        draft_input = input.text

    if direction < 0:
        if command_history_index == -1:
            command_history_index = command_history.size() - 1
        else:
            command_history_index = maxi(0, command_history_index - 1)
        _set_input_text(command_history[command_history_index], true)
    else:
        if command_history_index == -1:
            return
        command_history_index += 1
        if command_history_index >= command_history.size():
            command_history_index = -1
            _set_input_text(draft_input, true)
        else:
            _set_input_text(command_history[command_history_index], true)

func _set_input_text(value: String, move_caret_to_end: bool = true) -> void:
    suppress_input_change = true
    input.text = value
    suppress_input_change = false
    if move_caret_to_end:
        input.caret_column = input.text.length()
    _refresh_suggestions()

func _refresh_suggestions() -> void:
    if input == null:
        return

    var text = input.text
    active_suggestions = _get_command_suggestions(text)
    if active_suggestions.is_empty():
        selected_suggestion_index = -1
    else:
        selected_suggestion_index = clampi(selected_suggestion_index, 0, active_suggestions.size() - 1) if selected_suggestion_index >= 0 else 0
        
    if ghost_label != null:
        ghost_label.text = ""
        if text != "" and active_suggestions.size() > 0:
            var selected = active_suggestions[selected_suggestion_index]
            var insert_text = str(selected.get("insert", ""))
            
            var resulting_text = insert_text
            if not resulting_text.begins_with(text) and not text.ends_with(" "):
                var last_space = text.rfind(" ")
                if last_space != -1:
                    resulting_text = text.substr(0, last_space + 1) + insert_text
            
            if resulting_text.to_lower().begins_with(text.to_lower()) and resulting_text.length() > text.length():
                var completion = resulting_text.substr(text.length())
                ghost_label.text = "[color=transparent]" + _escape_bbcode(text) + "[/color][color=#a0a0a0]" + _escape_bbcode(completion) + "[/color]"

    _rebuild_suggestion_widgets()

func _get_command_suggestions(text: String) -> Array:
    if not text.begins_with("/"):
        return []
    if Ref.coop_manager != null and Ref.coop_manager.has_method("get_command_autocomplete_entries"):
        return Ref.coop_manager.get_command_autocomplete_entries(text)
    return []

func _rebuild_suggestion_widgets() -> void:
    pass

func _format_suggestion_label(suggestion: Dictionary) -> String:
    var display_text: String = str(suggestion.get("display", suggestion.get("insert", "")))
    var hint_text: String = str(suggestion.get("hint", ""))
    return display_text if hint_text == "" else "%s  -  %s" % [display_text, hint_text]

func _get_visible_suggestions() -> Array:
    var visible: Array = []
    if active_suggestions.is_empty():
        return visible

    var selected_index: int = clampi(selected_suggestion_index, 0, active_suggestions.size() - 1)
    var start_index: int = maxi(0, selected_index - MAX_VISIBLE_SUGGESTIONS + 1)
    if selected_index < MAX_VISIBLE_SUGGESTIONS:
        start_index = 0
    var end_index: int = mini(active_suggestions.size(), start_index + MAX_VISIBLE_SUGGESTIONS)
    for index in range(start_index, end_index):
        visible.append({
            "index": index,
            "data": active_suggestions[index],
        })
    return visible

func _cycle_suggestion(step: int) -> void:
    if active_suggestions.is_empty() or input == null:
        return

    if selected_suggestion_index < 0:
        selected_suggestion_index = 0 if step >= 0 else active_suggestions.size() - 1
    else:
        selected_suggestion_index = posmod(selected_suggestion_index + step, active_suggestions.size())
        
    var suggestion = active_suggestions[selected_suggestion_index]
    var insert_text = str(suggestion.get("insert", ""))
    if insert_text == "":
        return
        
    var text = input.text
    var resulting_text = insert_text
    
    if not resulting_text.to_lower().begins_with(text.to_lower()) and not text.ends_with(" "):
        var last_space = text.rfind(" ")
        if last_space != -1:
            resulting_text = text.substr(0, last_space + 1) + insert_text
            
    if not resulting_text.ends_with(" "):
        resulting_text += " "
            
    _set_input_text(resulting_text, true)
    input.grab_focus()

func _set_selected_suggestion(index: int) -> void:
    selected_suggestion_index = clampi(index, 0, active_suggestions.size() - 1)
    _rebuild_suggestion_widgets()

func _apply_suggestion(index: int, preserve_focus: bool = true) -> void:
    if index < 0 or index >= active_suggestions.size() or input == null:
        return
    selected_suggestion_index = index
    
    var suggestion = active_suggestions[selected_suggestion_index]
    var insert_text = str(suggestion.get("insert", ""))
    if insert_text == "":
        return
        
    var text = input.text
    var resulting_text = insert_text
    
    if not resulting_text.to_lower().begins_with(text.to_lower()) and not text.ends_with(" "):
        var last_space = text.rfind(" ")
        if last_space != -1:
            resulting_text = text.substr(0, last_space + 1) + insert_text
            
    if not resulting_text.ends_with(" "):
        resulting_text += " "
        
    _set_input_text(resulting_text, true)
    if preserve_focus:
        input.grab_focus()

func _capture_coop_status_message(force: bool = false) -> void:
    if Ref.coop_manager == null:
        return

    var status_text: String = str(Ref.coop_manager.status_message).strip_edges()
    if status_text == "":
        return
    if not force and status_text == last_status_message:
        return

    last_status_message = status_text
    if status_text == "Idle":
        return

    var color: String = SYSTEM_COLOR
    var lowered: String = status_text.to_lower()
    if lowered.contains("fail") or lowered.contains("error") or lowered.contains("unknown"):
        color = ERROR_COLOR
    elif lowered.contains("usage") or lowered.contains("spawn ids"):
        color = HINT_COLOR
    display_system_message(status_text, color)

func _push_history(text: String, color: String = SYSTEM_COLOR) -> void:
    var clean_text: String = text.replace("\n", " | ").replace("\r", " ").strip_edges()
    if clean_text.length() > MAX_HISTORY_MESSAGE_CHARS:
        clean_text = "%s..." % clean_text.substr(0, MAX_HISTORY_MESSAGE_CHARS - 3)
    if clean_text == "":
        return

    history_messages.append({
        "text": clean_text,
        "color": color,
        "time": Time.get_ticks_msec(),
    })
    while history_messages.size() > MAX_HISTORY_MESSAGES:
        history_messages.remove_at(0)
    _refresh_chat_visibility()

func _refresh_chat_visibility() -> void:
    if chat_margin == null or history_panel == null or history_label == null:
        return

    var visible_messages: Array[Dictionary] = _get_visible_messages()
    var show_input: bool = _is_open()
    var hide_for_other_menu: bool = _should_hide_passive_messages()
    var show_history: bool = not visible_messages.is_empty() and (show_input or not hide_for_other_menu)

    chat_margin.visible = show_input or show_history
    input_panel.visible = show_input
    history_panel.visible = show_history

    if show_history:
        history_panel.self_modulate = Color(1.0, 1.0, 1.0, 0.45 if show_input else 0.0)
        if history_scroll != null:
            history_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if show_input else ScrollContainer.SCROLL_MODE_SHOW_NEVER
        history_label.text = _build_history_bbcode(visible_messages)
        history_label.custom_minimum_size = Vector2(CHAT_WIDTH - 16.0, 9.0 * maxi(1, visible_messages.size()) + 2.0)

func _get_visible_messages() -> Array[Dictionary]:
    var visible_messages: Array[Dictionary] = []
    if history_messages.is_empty():
        return visible_messages

    if _is_open():
        var open_start: int = maxi(0, history_messages.size() - MAX_VISIBLE_OPEN_MESSAGES)
        for index in range(open_start, history_messages.size()):
            visible_messages.append(history_messages[index])
        return visible_messages

    var now_msec: int = Time.get_ticks_msec()
    for entry in history_messages:
        var age_sec: float = float(now_msec - int(entry.get("time", now_msec))) / 1000.0
        if age_sec <= CLOSED_MESSAGE_LIFETIME_SEC:
            visible_messages.append(entry)

    if visible_messages.size() > MAX_VISIBLE_CLOSED_MESSAGES:
        visible_messages = visible_messages.slice(visible_messages.size() - MAX_VISIBLE_CLOSED_MESSAGES, visible_messages.size())
    return visible_messages

func _build_history_bbcode(messages: Array[Dictionary]) -> String:
    var lines: PackedStringArray = PackedStringArray()
    for entry in messages:
        var line_text: String = _escape_bbcode(str(entry.get("text", "")))
        var line_color: String = str(entry.get("color", SYSTEM_COLOR))
        lines.append("[color=#%s]%s[/color]" % [line_color, line_text])
    return "\n".join(lines)

func _escape_bbcode(text: String) -> String:
    return text.replace("[", "\\[").replace("]", "\\]")

func _should_hide_passive_messages() -> bool:
    if _is_open():
        return false
    if is_instance_valid(Ref.game_menu) and int(Ref.game_menu.state) != 0:
        return true
    if Ref.coop_manager != null:
        if bool(Ref.coop_manager.panel_visible):
            return true
        if Ref.coop_manager.spawn_browser_overlay != null and bool(Ref.coop_manager.spawn_browser_overlay.visible):
            return true
    return false
