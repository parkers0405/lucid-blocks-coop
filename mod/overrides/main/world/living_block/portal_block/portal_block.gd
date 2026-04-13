class_name PortalBlock extends LivingBlock

@export var target_dimension: LucidBlocksWorld.Dimension = LucidBlocksWorld.Dimension.DEBUG

var embargo: bool = false


func _ready() -> void:
    Ref.save_file_manager.settings_updated.connect(_on_settings_updated)
    _on_settings_updated()
    %StopTimer.timeout.connect(_on_timeout)


func _on_timeout() -> void:
    embargo = false

    var new_player: AudioStreamPlayer3D = %PortalSound.duplicate()
    new_player.finished.connect(new_player.queue_free)
    get_tree().get_root().add_child(new_player)
    new_player.global_position = global_position + Vector3(0.5, 0.5, 0.5)
    new_player.play()

    %GlitchParticles.emitting = true


func _on_settings_updated() -> void:
    var shadow_quality: int = Ref.save_file_manager.settings_file.get_data("shadow_quality", 2)
    var light: OmniLight3D = %Light
    if shadow_quality == 0:
        light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
    else:
        light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE


func generate(_block_type: Block) -> void:
    embargo = true
    %StopTimer.start()
    %EmbargoAnimationPlayer.play("liven")


func interact(interactor: Entity) -> void:
    if not can_currently_interact(interactor):
        return
    super.interact(interactor)

    if Ref.coop_manager != null:
        if target_dimension == LucidBlocksWorld.Dimension.POCKET and Ref.coop_manager.has_method("prompt_pocket_dimension_choice"):
            Ref.coop_manager.prompt_pocket_dimension_choice(false)
        elif Ref.coop_manager.has_method("open_dimension_instance"):
            Ref.coop_manager.open_dimension_instance(int(target_dimension))
    else:
        Ref.main.teleport_to_dimension(target_dimension)


func can_currently_interact(interactor: Entity) -> bool:
    return not embargo and super.can_currently_interact(interactor) and interactor == Ref.player and target_dimension != Ref.world.current_dimension and Ref.world.current_dimension != LucidBlocksWorld.Dimension.CHALLENGE and Ref.world.current_dimension != LucidBlocksWorld.Dimension.YHVH


func preserve_load(file: SaveFile, uuid: String) -> void:
    super.preserve_load(file, uuid)
    %EmbargoAnimationPlayer.play("liven_immediate")
