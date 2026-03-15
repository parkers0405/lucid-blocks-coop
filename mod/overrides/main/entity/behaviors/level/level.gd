class_name Level extends Behavior

@export var available_perks: Array[Perk]
@export var base_max_tiamana: float = 2
@export var tiamana_flow: float = 1.5
@export var tiamana_music: AudioStream

@onready var level_up_pause_timer: Timer = %LevelUpPauseTimer

signal level_up_complete

var level: int = 0:
	set(val):
		level = val
		level_changed.emit(level)
var max_tiamana: float = 0.0:
	set(val):
		max_tiamana = val
		max_tiamana_changed.emit(max_tiamana)
var tiamana: float = 0.0:
	set(val):
		tiamana = maxf(val, 0.0)
		tiamana_changed.emit(tiamana)

var tiamana_store: float = 0.0
var flowing: bool = false:
	set(val):
		if not val == flowing:
			flow_status_changed.emit(val)
		flowing = val
var source: TiamanaSource = TiamanaSource.NONE:
	set(val):
		if not val == source:
			source_changed.emit(val)
		source = val
var flow_paused: bool = false

signal level_changed(value: int)
signal max_tiamana_changed(value: float)
signal tiamana_changed(value: float)
signal flow_status_changed(value: bool)
signal source_changed(new_source: TiamanaSource)

enum TiamanaSource{FUSION, CUTSCENE, NONE}


func _ready() -> void :
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_instance_valid(Ref.main):
		Ref.main.game_quit.connect(_on_game_quit)


func _on_game_quit() -> void :
	flowing = false


func _process(delta: float) -> void :
	if is_instance_valid(Ref.main) and Ref.main.creative:
		return

	flowing = ( not flow_paused and tiamana_store > 0.0 and not get_tree().paused and not entity.dead and enabled and not entity.disabled)

	if level_up_pause_timer.time_left > 0.0:
		return

	if flowing:
		var tiamana_to_add: float = minf(tiamana_store, tiamana_flow * delta)
		tiamana_store -= tiamana_to_add
		tiamana += tiamana_to_add

		if tiamana >= max_tiamana:
			level_up()


func preserve_save(file: SaveFile, uuid: String) -> void :
	var multidimensional: bool = uuid == "player"
	file.set_data("node/%s/tiamana" % uuid, tiamana, multidimensional)
	file.set_data("node/%s/tiamana_store" % uuid, tiamana_store, multidimensional)
	file.set_data("node/%s/tiamana_source" % uuid, source, multidimensional)
	file.set_data("node/%s/level" % uuid, level, multidimensional)


func preserve_load(file: SaveFile, uuid: String) -> void :
	var multidimensional: bool = uuid == "player"
	tiamana = file.get_data("node/%s/tiamana" % uuid, 0.0, multidimensional)
	tiamana_store = file.get_data("node/%s/tiamana_store" % uuid, 0.0, multidimensional)
	level = file.get_data("node/%s/level" % uuid, 0, multidimensional)
	source = file.get_data("node/%s/tiamana_source" % uuid, TiamanaSource.FUSION, multidimensional)
	update_max_tiamana()


func level_up() -> void :
	# Only the local player should see the level-up UI.
	# Non-player entities or remote proxies should just level up silently.
	if entity != Ref.player:
		_silent_level_up()
		return

	level += 1
	entity.faith += randi_range(0, 2)
	entity.lust += randi_range(0, 2)

	flow_paused = true

	# In coop, don't pause the whole tree - only disable the local player
	var in_coop: bool = Ref.coop_manager != null and Ref.coop_manager.has_active_session()
	if not in_coop:
		get_tree().paused = true

	var old_game_menu_state: int = Ref.game_menu.state
	Ref.game_menu.state = GameMenu.LEVELING_UP
	Ref.audio_manager.play_song(tiamana_music, 20, 5.0)

	%LevelUpPlayer.play()

	await Ref.trans.open_tiamana()

	tiamana -= max_tiamana
	update_max_tiamana()

	Ref.level_up_menu.open()
	await RenderingServer.frame_post_draw
	Ref.level_up_menu.initialize(get_next_level_up_perks())

	await Ref.trans.close_tiamana()

	Ref.level_up_menu.activate()
	var perk: Perk = await Ref.level_up_menu.select_perk()
	Ref.level_up_menu.deactivate()

	await Ref.trans.open()

	perk.activate()
	Ref.level_up_menu.close()

	Ref.audio_manager.stop_song(tiamana_music)

	level_up_complete.emit()

	await Ref.trans.close()

	if not in_coop:
		get_tree().paused = false
	Ref.game_menu.state = old_game_menu_state

	flow_paused = false
	level_up_pause_timer.start()


func _silent_level_up() -> void:
	level += 1
	entity.faith += randi_range(0, 2)
	entity.lust += randi_range(0, 2)
	tiamana -= max_tiamana
	update_max_tiamana()
	# Pick a random perk and apply it silently
	var perks: Array[Perk] = get_next_level_up_perks()
	if not perks.is_empty():
		perks[0].activate()
	level_up_complete.emit()
	level_up_pause_timer.start()


func get_next_level_up_perks() -> Array[Perk]:
	if is_instance_valid(Ref.world) and Ref.world.generator != null:
		seed(Ref.world.generator.seed * level * 7)
	var filtered_available_perks: Array[Perk] = []
	for perk in available_perks:
		if perk.is_available():
			filtered_available_perks.append(perk)

	var selected_perks: Array[Perk] = []
	var remaining_perks: Array[Perk] = filtered_available_perks.duplicate()

	while selected_perks.size() < 5 and remaining_perks.size() > 0:
		var total_weight: float = 0.0
		for perk in remaining_perks:
			total_weight += perk.proportion

		var roll: float = randf() * total_weight
		var cumulative: float = 0.0

		for i in range(remaining_perks.size()):
			cumulative += remaining_perks[i].proportion
			if roll <= cumulative:
				selected_perks.append(remaining_perks[i])
				remaining_perks.remove_at(i)
				break

	return selected_perks


func update_max_tiamana() -> void :
	max_tiamana = base_max_tiamana + level * 0.5


func give_tiamana(tiamana_boost: float, new_source: TiamanaSource) -> void :
	if is_instance_valid(Ref.main) and Ref.main.creative:
		return
	source = new_source
	tiamana_store += tiamana_boost * 1.05
