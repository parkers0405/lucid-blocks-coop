class_name Melt extends Behavior

@export var melt_stream: AudioStream
@export var melt_time: float = 3.5
@export var melt_sound: bool = false
@export var weather_weak: bool = true
@export var wrath_weak: bool = false
@export var check_distance: float = 128.0

var tween: Tween

var can_melt: bool = false:
	set(val):
		can_melt = val
		set_physics_process(can_melt)
		melting = false
		can_melt_state_reset = true
		if melt_sound:
			if is_instance_valid(tween) and tween.is_running():
				tween.stop()
			tween = get_tree().create_tween()
			if can_melt:
				tween.tween_property( %MeltingSound, "volume_db", -20, 1.0)
			else:
				tween.tween_property( %MeltingSound, "volume_db", -80, 1.0)
var melting: bool = false:
	set(val):
		melting = val and enabled and not entity.disabled
		if melting:
			if melt_sound:
				if is_instance_valid(tween) and tween.is_running():
					tween.stop()
				tween = get_tree().create_tween()
				tween.tween_property( %MeltingSound, "volume_db", -14, 1.0)
			%MeltTimer.start(melt_time)
		else:
			if melt_sound:
				if is_instance_valid(tween) and tween.is_running():
					tween.stop()
				tween = get_tree().create_tween()
				tween.tween_property( %MeltingSound, "volume_db", -64, 1.0)
			%MeltTimer.stop()
var can_melt_state_reset: bool = false


func _ready() -> void :
	super._ready()
	set_physics_process(false)
	if is_instance_valid(Ref.weather):
		Ref.weather.weather_override_changed.connect(_on_weather_changed)
	%MeltTimer.timeout.connect(_on_melt_timeout)
	if melt_sound:
		%MeltingSound.stream = melt_stream
		%MeltingSound.play()
	if is_instance_valid(Ref.weather):
		_on_weather_changed(Ref.weather.weather_override)


func _on_melt_timeout() -> void :
	if not enabled or entity.disabled or entity.dead:
		return
	entity.take_damage(1, Entity.FIRE)
	%MeltTimer.start(melt_time)


func _on_weather_changed(new_weather: String) -> void :
	can_melt = (wrath_weak and is_instance_valid(Ref.main) and Ref.main.wrathful_torus) or (new_weather == "acid rain" and weather_weak)


func _physics_process(_delta: float) -> void :
	# Use entity head position for raycast origin. For player entities,
	# check upside_down state only if this is the local player.
	var is_local_player: bool = entity == Ref.player
	var use_upside_down: bool = is_local_player and is_instance_valid(Ref.main) and Ref.main.upside_down
	%CheckRayCast.global_position = (entity.global_position if use_upside_down else entity.head.global_position)

	if wrath_weak and is_instance_valid(Ref.sun):
		%CheckRayCast.target_position = check_distance * Ref.sun.transform.basis.z
	else:
		%CheckRayCast.target_position = Vector3(0, check_distance, 0)

	if use_upside_down:
		%CheckRayCast.target_position *= -1

	var will_melt: bool = not (entity.head_under_water or %CheckRayCast.is_colliding())

	if wrath_weak and is_instance_valid(Ref.sun):
		will_melt = will_melt and Ref.sun.is_day()

	if melting != will_melt or can_melt_state_reset:
		melting = will_melt

	can_melt_state_reset = false


func preserve_save(_file: SaveFile, _uuid: String) -> void :
	pass


func preserve_load(_file: SaveFile, _uuid: String) -> void :
	if is_instance_valid(Ref.weather):
		_on_weather_changed(Ref.weather.weather_override)
