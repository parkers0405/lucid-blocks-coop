class_name Curse extends Behavior

@export var curse_songs: Array[AudioStream] = [preload("res://main/music/acid_reflux_a.ogg"), preload("res://main/music/acid_reflux_b.ogg"), preload("res://main/music/acid_reflux_c.ogg")]
@export var curse_time: float = 15.0

var delusion: float = 0.0:
    set(val):
        delusion = clamp(val, 0.0, 1.0)
        delusion_changed.emit(delusion)
var is_cursed: bool = false
var current_curse_song: AudioStream
var tween: Tween

signal delusion_changed(delusion: float)


func _ready() -> void:
    super._ready()
    assert(entity is Player or (entity is Entity and entity.is_session_player_entity(entity)))
    Ref.main.game_quit.connect(_on_game_quit)


func _on_game_quit() -> void:
    if is_instance_valid(tween) and tween.is_running():
        tween.kill()
    if current_curse_song != null:
        Ref.audio_manager.stop_song(current_curse_song)
        current_curse_song = null


func curse() -> void:
    if not enabled or entity.disabled or is_cursed:
        return
    if is_instance_valid(tween) and tween.is_running():
        tween.kill()
    tween = get_tree().create_tween()
    tween.tween_property(self, "delusion", 1.0, 3.0)
    is_cursed = true

    current_curse_song = curse_songs.pick_random()
    Ref.audio_manager.play_song(current_curse_song, 3, 2.0)


func uncurse() -> void:
    if not enabled or entity.disabled or not is_cursed:
        return
    if is_instance_valid(tween) and tween.is_running():
        tween.kill()
    tween = get_tree().create_tween()
    tween.tween_property(self, "delusion", 0.0, 3.0)
    is_cursed = false

    if current_curse_song != null:
        Ref.audio_manager.stop_song(current_curse_song)
        current_curse_song = null


func preserve_save(file: SaveFile, uuid: String) -> void:
    var multidimensional: bool = uuid == "player"
    file.set_data("node/%s/curse/is_cursed" % uuid, is_cursed, multidimensional)


func preserve_load(file: SaveFile, uuid: String) -> void:
    var multidimensional: bool = uuid == "player"
    is_cursed = file.get_data("node/%s/curse/is_cursed" % uuid, false, multidimensional)
    if is_cursed:
        delusion = 1.0
        current_curse_song = curse_songs.pick_random()
        Ref.audio_manager.play_song(current_curse_song, 3, 1.0)
    else:
        delusion = 0.0
