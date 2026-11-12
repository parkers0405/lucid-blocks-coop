extends CanvasLayer

var manager: Node
var block: Node3D
var instance_key: String
var session: String = ""
var revision: int = 0
var selected: int = 0
var record: Dictionary = {}
var busy: bool = true
var rows: VBoxContainer
var slots: GridContainer
var quantity: SpinBox
var status: Label
var help: Label
var selected_item: Label
var backdrop: PanelContainer
var restore_capture: bool = false
var transfer_buttons: Array[Button] = []

func start(owner_manager: Node, access_block: Node3D) -> void:
    manager = owner_manager
    block = access_block
    instance_key = manager.get_active_dimension_instance_key()
    layer = 110
    manager.begin_chest_inventory_lock()
    restore_capture = MouseHandler.captured
    MouseHandler.release()
    var shield := ColorRect.new()
    shield.color = Color(0, 0, 0, 0.65)
    shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shield)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "top", "right", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 8)
    add_child(margin)
    var center := CenterContainer.new()
    margin.add_child(center)
    backdrop = PanelContainer.new()
    backdrop.theme = Theme.new()
    backdrop.theme.default_font_size = 11
    backdrop.theme.set_constant("separation", "BoxContainer", 2)
    center.add_child(backdrop)
    var layout := VBoxContainer.new()
    backdrop.add_child(layout)
    status = Label.new()
    status.text = "Opening personal chest..."
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(status)
    help = Label.new()
    help.text = "Select a chest slot. Store/Take moves the chosen quantity."
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(help)
    slots = GridContainer.new()
    slots.columns = 7
    layout.add_child(slots)
    selected_item = Label.new()
    selected_item.text = "Choose a chest slot"
    selected_item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    layout.add_child(selected_item)
    var quantity_row := HBoxContainer.new()
    layout.add_child(quantity_row)
    var quantity_label := Label.new()
    quantity_label.text = "Quantity"
    quantity_row.add_child(quantity_label)
    quantity = SpinBox.new()
    quantity.min_value = 1
    quantity.max_value = 1
    quantity.value = 1
    quantity.editable = false
    quantity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    quantity.value_changed.connect(_refresh_transfer_controls)
    quantity_row.add_child(quantity)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.follow_focus = true
    layout.add_child(scroll)
    rows = VBoxContainer.new()
    rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(rows)
    var close := Button.new()
    close.text = "Close"
    close.pressed.connect(queue_free)
    layout.add_child(close)
    close.call_deferred("grab_focus")
    get_viewport().size_changed.connect(_resize_panel)
    _resize_panel()

func _resize_panel() -> void:
    var available: Vector2 = get_viewport().get_visible_rect().size - Vector2(16, 16)
    backdrop.custom_minimum_size = Vector2(minf(650, available.x), minf(600, available.y))
    slots.columns = clampi(int((available.x - 16) / 40), 1, 7)
    help.visible = available.y > 360

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        queue_free()
        get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
    if not is_instance_valid(block) or not is_instance_valid(Ref.player):
        queue_free()
        return
    if block.broken or Ref.player.dead or manager.reconnect_pending:
        queue_free()
        return
    if manager.get_active_dimension_instance_key() != instance_key or Ref.player.global_position.distance_to(block.global_position) > 8.0:
        queue_free()

func _exit_tree() -> void:
    if not is_instance_valid(manager):
        return
    manager.close_personal_chest(session)
    if restore_capture and not manager.reconnect_pending and not manager.client_restore_in_progress and not manager.receiving_host_world and is_instance_valid(Ref.player) and not Ref.player.dead and is_instance_valid(Ref.main) and Ref.main.loaded and is_instance_valid(Ref.game_menu) and int(Ref.game_menu.state) != 4:
        MouseHandler.capture()

func item_text(data: Variant) -> String:
    if not data is PackedInt32Array or data.is_empty():
        return "Empty"
    var item = ItemMap.map(data[0])
    var name: String = str(data[0])
    if item != null:
        name = str(item.display_name)
    return "%s x%d" % [name, data[1]]

func receive(result: Dictionary, token: String) -> void:
    if result.is_empty():
        busy = false
        _refresh_transfer_controls()
        status.text = "Chest unavailable. Close and try again." if record.is_empty() else "Item could not be moved. Try another slot or quantity."
        return
    session = token
    record = result
    revision = result["revision"]
    busy = false
    redraw()

func redraw() -> void:
    status.text = "Personal chest: slot %d / 21" % (selected + 1)
    transfer_buttons.clear()
    for child in slots.get_children():
        child.free()
    for index in range(21):
        var button := Button.new()
        button.custom_minimum_size = Vector2(36, 20)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.clip_text = true
        button.toggle_mode = true
        button.button_pressed = index == selected
        var entry = record["chest"][index]
        var item = entry.get("item") if entry is Dictionary else null
        button.text = str(index + 1) if item == null else "%d: x%d" % [index + 1, item[1]]
        button.tooltip_text = "%d: %s" % [index + 1, item_text(item)]
        button.pressed.connect(_select_slot.bind(index))
        slots.add_child(button)
    for child in rows.get_children():
        child.free()
    for inventory_name in ["Hotbar", "Inventory"]:
        var inventory: Dictionary = record["state"].get("node", {}).get("player", {}).get(inventory_name, {})
        var items: Array = inventory.get("items", [])
        for index in range(items.size() / 2):
            var row := HBoxContainer.new()
            rows.add_child(row)
            var label := Label.new()
            label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            label.clip_text = true
            label.text = "%s %d: %s" % [inventory_name, index + 1, item_text(items[index * 2])]
            label.tooltip_text = label.text
            row.add_child(label)
            for deposit in [true, false]:
                var button := Button.new()
                button.text = "Store" if deposit else "Take"
                button.set_meta("transfer", [inventory_name, index, deposit])
                button.pressed.connect(_request_transfer.bind(inventory_name, index, deposit))
                row.add_child(button)
                transfer_buttons.append(button)
    _select_slot(selected)

func _select_slot(index: int) -> void:
    selected = index
    for slot in slots.get_children():
        slot.button_pressed = slot.get_index() == selected
    status.text = "Personal chest: slot %d / 21" % (selected + 1)
    var entry = record["chest"][selected]
    selected_item.text = item_text(entry.get("item") if entry is Dictionary else null)
    selected_item.tooltip_text = selected_item.text
    _refresh_transfer_controls()

func _transfer_limit(inventory_name: String, index: int, deposit: bool) -> int:
    if record.is_empty():
        return 0
    var items: Array = record["state"].get("node", {}).get("player", {}).get(inventory_name, {}).get("items", [])
    if index * 2 + 1 >= items.size():
        return 0
    var entry = record["chest"][selected]
    var chest_item = entry.get("item") if entry is Dictionary else null
    var chest_position: Vector3i = entry.get("position", Vector3i.ZERO) if entry is Dictionary else Vector3i.ZERO
    var source = items[index * 2] if deposit else chest_item
    var destination = chest_item if deposit else items[index * 2]
    if not source is PackedInt32Array or source.size() != 3:
        return 0
    var item = ItemMap.map(source[0])
    var maximum: int = int(item.stack_size) if item != null else 0
    if source[1] > maximum:
        return 0
    var existing: int = 0
    if destination is PackedInt32Array and not destination.is_empty():
        if destination.size() != 3 or destination[0] != source[0] or destination[2] != source[2] or items[index * 2 + 1] != chest_position:
            return 0
        existing = destination[1]
    return maxi(0, mini(source[1], maximum - existing))

func _refresh_transfer_controls(_value: float = 0.0) -> void:
    var maximum: int = 1
    for button in transfer_buttons:
        var operation: Array = button.get_meta("transfer")
        maximum = maxi(maximum, _transfer_limit(operation[0], operation[1], operation[2]))
    quantity.set_block_signals(true)
    quantity.max_value = maximum
    quantity.set_block_signals(false)
    quantity.editable = not busy and not record.is_empty()
    for slot in slots.get_children():
        slot.disabled = busy
    for button in transfer_buttons:
        var operation: Array = button.get_meta("transfer")
        button.disabled = busy or _transfer_limit(operation[0], operation[1], operation[2]) < int(quantity.value)

func _request_transfer(inventory_name: String, index: int, deposit: bool) -> void:
    if busy or _transfer_limit(inventory_name, index, deposit) < int(quantity.value):
        return
    busy = true
    status.text = "Moving items..."
    _refresh_transfer_controls()
    manager.transfer_personal_chest.call_deferred(session, revision, inventory_name, index, selected, int(quantity.value), deposit)
