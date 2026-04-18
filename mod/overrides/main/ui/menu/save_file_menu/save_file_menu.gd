class_name SaveFileMenu extends Menu

@export var save_file_container_scene: PackedScene

var deleting: bool = false

signal new_world_requested
signal edit_requested(file: SaveFileRegister)
signal delete_requested(file: SaveFileRegister)
signal play_requested(file: SaveFileRegister)
signal firmament_requested
signal delete_request(confirm: bool)


func _ready() -> void:
    %ExitButton.pressed.connect(emit_signal.bind("exited"))
    %FirmamentButton.pressed.connect(emit_signal.bind("firmament_requested"))
    %DeleteButton.pressed.connect(emit_signal.bind("delete_request", true))
    %CancelButton.pressed.connect(emit_signal.bind("delete_request", false))
    %ConfirmContainer.visible = false
    %ConfirmContainer.modulate.a = 0.0
    %MouseBlock.visible = false


func _input(event: InputEvent) -> void:
    if active and event.is_action_pressed("back", false):
        if deleting:
            delete_request.emit(false)
        else:
            exited.emit()


func _on_delete_requested(file: SaveFileRegister) -> void:
    deleting = true
    for child in %DeleteHolder.get_children():
        child.queue_free()

    var new_panel: SaveFileContainer = save_file_container_scene.instantiate()
    %DeleteHolder.add_child(new_panel)
    new_panel.initialize(file, false, false, false)
    new_panel.allow_hover = false

    %ConfirmContainer.visible = true
    %MouseBlock.visible = true

    var tween: Tween = get_tree().create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(%ConfirmContainer, "modulate:a", 1.0, 0.125)
    await tween.finished
    %MouseBlock.visible = false
    var delete: bool = await delete_request
    %MouseBlock.visible = true

    if delete:
        delete_requested.emit(file)

    tween = get_tree().create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(%ConfirmContainer, "modulate:a", 0.0, 0.125)
    await tween.finished

    for child in %DeleteHolder.get_children():
        child.queue_free()

    %ConfirmContainer.visible = false
    %MouseBlock.visible = false
    deleting = false


func _on_new_world_pressed() -> void:
    new_world_requested.emit()


func open() -> void:
    visible = true
    %ScrollContainer.scroll_vertical = 0
    update_save_files()


func update_save_files() -> void:
    for child in %SaveFileVBoxContainer.get_children():
        child.queue_free()

    var new_instance_panel: SaveFileContainer = save_file_container_scene.instantiate()
    %SaveFileVBoxContainer.add_child(new_instance_panel)
    new_instance_panel.initialize(null, true)
    new_instance_panel.play_button_pressed.connect(_on_new_world_pressed)

    for file in Ref.save_file_manager.get_save_file_registers():
        var new_panel: SaveFileContainer = save_file_container_scene.instantiate()
        %SaveFileVBoxContainer.add_child(new_panel)
        new_panel.initialize(file, false, true, file.is_downloaded)

        new_panel.play_button_pressed.connect(emit_signal.bind("play_requested", file))
        new_panel.delete_button_pressed.connect(_on_delete_requested.bind(file))
        new_panel.edit_button_pressed.connect(emit_signal.bind("edit_requested", file))
 
