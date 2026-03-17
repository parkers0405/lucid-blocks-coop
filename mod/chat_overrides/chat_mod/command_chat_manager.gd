extends Node


const MAX_HISTORY_MESSAGES: int = 64
const MAX_COMMAND_HISTORY: int = 32
const MAX_VISIBLE_OPEN_MESSAGES: int = 12
const MAX_VISIBLE_CLOSED_MESSAGES: int = 2
const MAX_VISIBLE_SUGGESTIONS: int = 8
const CLOSED_MESSAGE_LIFETIME_SEC: float = 12.0
const MAX_HISTORY_MESSAGE_CHARS: int = 84
const CHAT_WIDTH: float = 560.0
const COMMAND_COLOR: String = "d7e3ff"
const SYSTEM_COLOR: String = "f3efe2"
const ERROR_COLOR: String = "ff9b91"
const HINT_COLOR: String = "a9b7d0"


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
var previous_game_menu_active: bool = true

var restore_capture_on_close: bool = false
var suppress_input_change: bool = false
var history_messages: Array[Dictionary] = []
var command_history: PackedStringArray = PackedStringArray()
var command_history_index: int = -1
var draft_input: String = ""
var last_status_message: String = ""
var active_suggestions: Array[Dictionary] = []
var selected_suggestion_index: int = -1


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
    chat_margin.offset_left = 10.0
    chat_margin.offset_top = -336.0
    chat_margin.offset_right = CHAT_WIDTH + 10.0
    chat_margin.offset_bottom = -10.0
    hud.add_child(chat_margin)

    chat_stack = VBoxContainer.new()
    chat_stack.alignment = BoxContainer.ALIGNMENT_END
    chat_stack.add_theme_constant_override("separation", 4)
    chat_margin.add_child(chat_stack)

    history_panel = PanelContainer.new()
    history_panel.visible = false
    history_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    history_panel.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
    history_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    history_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    chat_stack.add_child(history_panel)

    var history_margin := MarginContainer.new()
    history_margin.add_theme_constant_override("margin_left", 0)
    history_margin.add_theme_constant_override("margin_right", 0)
    history_margin.add_theme_constant_override("margin_top", 0)
    history_margin.add_theme_constant_override("margin_bottom", 0)
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
    history_label.custom_minimum_size = Vector2(CHAT_WIDTH - 16.0, 24.0)
    history_label.add_theme_font_size_override("normal_font_size", 15)
    history_scroll.add_child(history_label)

    suggestion_panel = PanelContainer.new()
    suggestion_panel.visible = false
    suggestion_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    suggestion_panel.self_modulate = Color(0.0, 0.0, 0.0, 0.72)
    suggestion_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    chat_stack.add_child(suggestion_panel)

    var suggestion_margin := MarginContainer.new()
    suggestion_margin.add_theme_constant_override("margin_left", 6)
    suggestion_margin.add_theme_constant_override("margin_right", 6)
    suggestion_margin.add_theme_constant_override("margin_top", 5)
    suggestion_margin.add_theme_constant_override("margin_bottom", 5)
    suggestion_panel.add_child(suggestion_margin)

    var suggestion_column := VBoxContainer.new()
    suggestion_column.add_theme_constant_override("separation", 2)
    suggestion_margin.add_child(suggestion_column)

    suggestion_title_label = Label.new()
    suggestion_title_label.visible = false
    suggestion_title_label.add_theme_font_size_override("font_size", 12)
    suggestion_title_label.add_theme_color_override("font_color", Color(0.90, 0.93, 1.0))
    suggestion_column.add_child(suggestion_title_label)

    suggestion_scroll = ScrollContainer.new()
    suggestion_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    suggestion_scroll.follow_focus = true
    suggestion_column.add_child(suggestion_scroll)

    suggestion_list = VBoxContainer.new()
    suggestion_list.add_theme_constant_override("separation", 1)
    suggestion_scroll.add_child(suggestion_list)

    suggestion_hint_label = Label.new()
    suggestion_hint_label.visible = false
    suggestion_hint_label.add_theme_font_size_override("font_size", 10)
    suggestion_hint_label.add_theme_color_override("font_color", Color(0.70, 0.76, 0.84))
    suggestion_column.add_child(suggestion_hint_label)

    input_panel = PanelContainer.new()
    input_panel.visible = false
    input_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    input_panel.self_modulate = Color(0.0, 0.0, 0.0, 0.84)
    input_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    chat_stack.add_child(input_panel)

    var input_margin := MarginContainer.new()
    input_margin.add_theme_constant_override("margin_left", 6)
    input_margin.add_theme_constant_override("margin_right", 6)
    input_margin.add_theme_constant_override("margin_top", 4)
    input_margin.add_theme_constant_override("margin_bottom", 4)
    input_panel.add_child(input_margin)

    input = LineEdit.new()
    input.placeholder_text = "/command"
    input.clear_button_enabled = false
    input.custom_minimum_size = Vector2(CHAT_WIDTH - 12.0, 34.0)
    input.add_theme_font_size_override("font_size", 16)
    input.text_changed.connect(_on_input_text_changed)
    input.text_submitted.connect(_on_text_submitted)
    input_margin.add_child(input)


func _refresh_chat_layout() -> void:
    if get_viewport() == null or chat_margin == null or history_label == null or input == null:
        return

    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var chat_width: float = minf(CHAT_WIDTH, maxf(180.0, viewport_size.x - 20.0))
    var target_height: float = 0.0
    if _is_open():
        target_height = 212.0 if not active_suggestions.is_empty() else 148.0
    else:
        var passive_count: int = mini(MAX_VISIBLE_CLOSED_MESSAGES, _get_visible_messages().size())
        target_height = 4.0 + passive_count * 16.0 if passive_count > 0 else 0.0
    var chat_height: float = minf(target_height, maxf(76.0, viewport_size.y - 20.0))
    chat_margin.offset_left = 10.0
    chat_margin.offset_right = 10.0 + chat_width
    chat_margin.offset_bottom = -10.0
    chat_margin.offset_top = -10.0 - chat_height

    history_label.custom_minimum_size.x = maxf(120.0, chat_width - 16.0)
    input.custom_minimum_size.x = maxf(120.0, chat_width - 12.0)

    var input_height: float = 44.0 if _is_open() else 0.0
    var suggestion_height: float = 0.0
    if _is_open() and not active_suggestions.is_empty():
        suggestion_height = minf(90.0, maxf(48.0, chat_height * 0.32))
    var history_height: float = maxf(18.0 if _is_open() else 12.0, chat_height - input_height - suggestion_height - 4.0)
    if history_scroll != null:
        history_scroll.custom_minimum_size = Vector2(maxf(120.0, chat_width - 16.0), history_height)
        history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    if suggestion_scroll != null:
        suggestion_scroll.custom_minimum_size = Vector2(maxf(120.0, chat_width - 12.0), suggestion_height)


func _can_open_chat() -> bool:
    return is_instance_valid(Ref.main) \
        and is_instance_valid(Ref.world) \
        and Ref.main.loaded \
        and Ref.world.load_enabled \
        and get_viewport().gui_get_focus_owner() == null


func _is_open() -> bool:
    return input_panel != null and input_panel.visible


func _open_chat(initial_text: String = "/") -> void:
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
    if text == "/tp" and not active_suggestions.is_empty():
        var selected_index: int = clampi(selected_suggestion_index, 0, active_suggestions.size() - 1)
        text = str(active_suggestions[selected_index].get("insert", text)).strip_edges()
    _close_chat(true)
    if text == "" or text == "/":
        return

    if not text.begins_with("/"):
        _push_history("Only slash commands are supported right now.", ERROR_COLOR)
        return

    _record_command_history(text)
    _push_history(text, COMMAND_COLOR)

    if Ref.coop_manager == null or not Ref.coop_manager.has_method("execute_command"):
        _push_history("Commands are unavailable right now.", ERROR_COLOR)
        return

    Ref.coop_manager.execute_command(text)
    _capture_coop_status_message(true)


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

    active_suggestions = _get_command_suggestions(input.text)
    if active_suggestions.is_empty():
        selected_suggestion_index = -1
    else:
        selected_suggestion_index = clampi(selected_suggestion_index, 0, active_suggestions.size() - 1) if selected_suggestion_index >= 0 else 0
    _rebuild_suggestion_widgets()


func _get_command_suggestions(text: String) -> Array:
    if not text.begins_with("/"):
        return []
    if Ref.coop_manager != null and Ref.coop_manager.has_method("get_command_autocomplete_entries"):
        return Ref.coop_manager.get_command_autocomplete_entries(text)
    return _get_fallback_command_suggestions(text)


func _get_fallback_command_suggestions(text: String) -> Array:
    var suggestions: Array = []
    var commands: Array = ["/host", "/join", "/tp", "/gamemode", "/spawn", "/spawnlist", "/avatar"]
    for command_text in commands:
        if text == "/" or command_text.begins_with(text):
            suggestions.append({
                "insert": command_text,
                "display": command_text,
                "hint": "Command",
            })
    return suggestions


func _rebuild_suggestion_widgets() -> void:
    if suggestion_panel == null or suggestion_list == null:
        return

    for child in suggestion_list.get_children():
        child.queue_free()

    var visible_suggestions: Array = _get_visible_suggestions()
    suggestion_panel.visible = _is_open() and not visible_suggestions.is_empty()
    suggestion_hint_label.visible = suggestion_panel.visible
    suggestion_title_label.visible = suggestion_panel.visible
    if not suggestion_panel.visible:
        suggestion_title_label.text = ""
        suggestion_hint_label.text = ""
        return

    var first_visible_index: int = int(visible_suggestions[0].get("index", 0))
    var total_count: int = active_suggestions.size()
    suggestion_title_label.text = _get_suggestion_title()
    suggestion_hint_label.text = "Tab cycles hints, click to fill, Enter runs command  (%d/%d)" % [selected_suggestion_index + 1, total_count]

    for entry in visible_suggestions:
        var actual_index: int = int(entry.get("index", 0))
        var suggestion: Dictionary = entry.get("data", {})
        var button := Button.new()
        button.flat = true
        button.focus_mode = Control.FOCUS_NONE
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.clip_text = true
        button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        button.text = _format_suggestion_label(suggestion)
        button.add_theme_font_size_override("font_size", 13)
        button.self_modulate = Color(0.94, 0.97, 1.0) if actual_index == selected_suggestion_index else Color(0.82, 0.87, 0.94)
        button.mouse_entered.connect(_set_selected_suggestion.bind(actual_index))
        button.pressed.connect(_apply_suggestion.bind(actual_index))
        suggestion_list.add_child(button)

    if first_visible_index > 0:
        var prefix := Label.new()
        prefix.text = "..."
        prefix.add_theme_font_size_override("font_size", 10)
        prefix.add_theme_color_override("font_color", Color(0.68, 0.73, 0.80))
        suggestion_list.add_child(prefix)
        suggestion_list.move_child(prefix, 0)
    var last_visible_index: int = int(visible_suggestions[visible_suggestions.size() - 1].get("index", total_count - 1))
    if last_visible_index < total_count - 1:
        var suffix := Label.new()
        suffix.text = "..."
        suffix.add_theme_font_size_override("font_size", 10)
        suffix.add_theme_color_override("font_color", Color(0.68, 0.73, 0.80))
        suggestion_list.add_child(suffix)


func _format_suggestion_label(suggestion: Dictionary) -> String:
    var display_text: String = str(suggestion.get("display", suggestion.get("insert", "")))
    var hint_text: String = str(suggestion.get("hint", ""))
    return display_text if hint_text == "" else "%s  -  %s" % [display_text, hint_text]


func _get_suggestion_title() -> String:
    var current_text: String = input.text.strip_edges().to_lower()
    if current_text.begins_with("/tp"):
        return "Teleport To"
    if current_text.begins_with("/spawn"):
        return "Spawn Mob"
    return "Command Suggestions"


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
    _apply_suggestion(selected_suggestion_index, false)


func _set_selected_suggestion(index: int) -> void:
    selected_suggestion_index = clampi(index, 0, active_suggestions.size() - 1)
    _rebuild_suggestion_widgets()


func _apply_suggestion(index: int, preserve_focus: bool = true) -> void:
    if index < 0 or index >= active_suggestions.size() or input == null:
        return
    selected_suggestion_index = index
    _set_input_text(str(active_suggestions[index].get("insert", input.text)), true)
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
    _push_history(status_text, color)


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
    suggestion_panel.visible = show_input and not active_suggestions.is_empty()

    if show_history:
        history_panel.self_modulate = Color(0.0, 0.0, 0.0, 0.82 if show_input else 0.55)
        history_label.text = _build_history_bbcode(visible_messages)
        history_label.custom_minimum_size = Vector2(CHAT_WIDTH - 16.0, 18.0 * maxi(1, visible_messages.size()) + 6.0)


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
