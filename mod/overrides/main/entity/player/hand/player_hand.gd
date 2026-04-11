class_name PlayerHand extends Node2D

@export var hand_path: String = "res://main/entity/player/hand/hand_variants/"

@onready var offset: Vector2 = %Offset.position

var current_hand: PlayerHandVariant
var left_handed: bool = false

var default_hand: PlayerHandVariant
var misc_hand: PlayerHandVariant


func _ready() -> void :
    print("Loading hand sprites...")
    load_and_instance_scenes(hand_path)
    print("Done loading hand sprites.")

    Ref.save_file_manager.settings_updated.connect(_on_settings_updated)
    _on_settings_updated()


func load_and_instance_scenes(dir_path: String) -> void :
    var dir: DirAccess = DirAccess.open(dir_path)

    dir.list_dir_begin()

    var file_name: String = dir.get_next()
    while file_name != "":
        var full_path: String = dir_path.path_join(file_name)
        if dir.current_is_dir():
            load_and_instance_scenes(full_path)
        elif ".tscn" in full_path:
            var fixed_path: String = full_path.replace(".remap", "")
            var resource: Resource = ResourceLoader.load(fixed_path)
            var scene: PackedScene = resource as PackedScene
            if scene:
                var instance: PlayerHandVariant = scene.instantiate() as PlayerHandVariant
                if instance:
                    %VariantHolder.add_child(instance)
                    instance.visible = false

                    if instance.name == "Default":
                        default_hand = instance
                    if instance.name == "ActualMisc":
                        misc_hand = instance
                else:
                    push_error("Failed to load scene: " + full_path)
            else:
                push_error("Failed to load scene: " + full_path)
        file_name = dir.get_next()
    dir.list_dir_end()


func _on_settings_updated() -> void :
    left_handed = Ref.save_file_manager.settings_file.get_data("left_hand", false)
    scale.x = abs(scale.x) * (-1.0 if left_handed else 1.0)
    set_hand_color()


func _resolve_hand_variant(item_state: ItemState) -> PlayerHandVariant:
    var next_hand: PlayerHandVariant = default_hand
    if item_state == null:
        return next_hand

    next_hand = misc_hand
    var item: Item = ItemMap.map(item_state.id)
    for child in %VariantHolder.get_children():
        if child.matches_with_item(item):
            next_hand = child
            break
    next_hand.initialize(item)
    return next_hand


func switch_item(held_item: HeldItem, item_state: ItemState) -> void :
    var next_hand: PlayerHandVariant = _resolve_hand_variant(item_state)

    if is_instance_valid(current_hand) and current_hand == next_hand:
        current_hand.open(held_item, item_state)
        return

    if is_instance_valid(current_hand):
        current_hand.reset()

    for child in %VariantHolder.get_children():
        if child is PlayerHandVariant:
            child.close()
    next_hand.open(held_item, item_state)

    current_hand = next_hand
    next_hand.idle()


func interact() -> void :
    current_hand.interact()


func interact_sustain_start() -> void :
    current_hand.interact_sustain_start()


func interact_sustain_end() -> void :
    current_hand.interact_sustain_end()


func hit() -> void :
    current_hand.hit()


func hit_sustain_start() -> void :
    current_hand.hit_sustain_start()


func hit_sustain_end() -> void :
    current_hand.hit_sustain_end()


func idle() -> void :
    current_hand.idle()


func set_hand_color() -> void :
    for hand in %VariantHolder.get_children():
        for sprite in hand.get_children():
            sprite.set_instance_shader_parameter("modulate", Ref.save_file_manager.settings_file.get_data("skin_modulate", Color.WHITE))
