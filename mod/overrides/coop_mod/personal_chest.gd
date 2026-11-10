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

func start(owner_manager: Node, access_block: Node3D) -> void:
    manager = owner_manager
    block = access_block
    instance_key = manager.get_active_dimension_instance_key()
    layer = 110
    manager.begin_chest_inventory_lock()
    MouseHandler.release()
    var shield := ColorRect.new()
    shield.color = Color(0, 0, 0, 0.65)
    shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shield)
    var backdrop := PanelContainer.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    backdrop.position = Vector2(50, 40)
    backdrop.size = Vector2(650, 600)
    add_child(backdrop)
    var layout := VBoxContainer.new()
    backdrop.add_child(layout)
    status = Label.new()
    status.text = "Personal chest — loading"
    layout.add_child(status)
    var help := Label.new()
    help.text = "Select a chest slot. Store/Take moves the chosen quantity."
    layout.add_child(help)
    slots = GridContainer.new()
    slots.columns = 7
    layout.add_child(slots)
    quantity = SpinBox.new()
    quantity.min_value = 1
    quantity.max_value = 999
    quantity.value = 1
    layout.add_child(quantity)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(600, 310)
    layout.add_child(scroll)
    rows = VBoxContainer.new()
    scroll.add_child(rows)
    var close := Button.new()
    close.text = "Close"
    close.pressed.connect(func():
        if not busy:
            queue_free()
    )
    layout.add_child(close)

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
    MouseHandler.capture()
    manager.close_personal_chest(session)

func item_text(data: Variant) -> String:
    if not data is PackedInt32Array or data.is_empty():
        return "Empty"
    var item = ItemMap.map(data[0])
    var name: String = str(data[0])
    if item != null:
        name = str(item.display_name)
    return "%s ×%d" % [name, data[1]]

func receive(result: Dictionary, token: String) -> void:
    if result.is_empty():
        status.text = "Chest transaction failed; close and reopen to retry"
        busy = false
        return
    session = token
    record = result
    revision = result["revision"]
    busy = false
    redraw()

func redraw() -> void:
    status.text = "Personal chest — slot %d / 21" % (selected + 1)
    for child in slots.get_children():
        child.free()
    for index in range(21):
        var button := Button.new()
        button.custom_minimum_size.x = 80
        button.clip_text = true
        var entry = record["chest"][index]
        button.text = "%d: %s" % [index + 1, item_text(entry.get("item") if entry is Dictionary else null)]
        button.tooltip_text = button.text
        button.pressed.connect(func():
            selected = index
            status.text = "Personal chest — slot %d / 21" % (selected + 1)
        )
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
            label.custom_minimum_size.x = 350
            label.text = "%s %d: %s" % [inventory_name, index + 1, item_text(items[index * 2])]
            row.add_child(label)
            for deposit in [true, false]:
                var button := Button.new()
                button.text = "Store →" if deposit else "← Take"
                button.pressed.connect(_request_transfer.bind(inventory_name, index, deposit))
                row.add_child(button)

func _request_transfer(inventory_name: String, index: int, deposit: bool) -> void:
    if busy:
        return
    busy = true
    status.text = "Saving transaction…"
    manager.transfer_personal_chest.call_deferred(session, revision, inventory_name, index, selected, int(quantity.value), deposit)
