extends Node2D
## Rain over a level, on and off through the day. Fine streaks driven by the
## same wind as the weather's gusts, a little heavier at the ground, and a
## hiss under it. Comes and goes on its own: a spell of rain every so often,
## fading in and out rather than switching.

@export var area_center := Vector2(576, 208)
@export var area_size := Vector2(1628, 576)
@export var wind := Vector2(-0.35, 1.0)
@export var drops := 340
## Seconds of dry between spells (min/max) and how long a spell lasts.
@export var dry_min := 90.0
@export var dry_max := 240.0
@export var spell_min := 45.0
@export var spell_max := 120.0
## Start raining on load. Otherwise the first spell comes after a dry gap.
@export var start_wet := false
@export var hiss := "res://audio/ambience/rain_loop.wav"
@export var hiss_db := -14.0

var raining := false
var _p: CPUParticles2D
var _timer := 0.0
var _level := 0.0            ## 0 dry .. 1 full


func _ready() -> void:
	_p = CPUParticles2D.new()
	_p.amount = drops
	_p.lifetime = 1.1
	_p.preprocess = 1.1
	_p.local_coords = false
	_p.position = area_center
	_p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_p.emission_rect_extents = area_size * 0.5
	_p.direction = wind.normalized()
	_p.spread = 3.0
	_p.gravity = Vector2.ZERO
	_p.initial_velocity_min = 220.0
	_p.initial_velocity_max = 300.0
	_p.angle_min = rad_to_deg(wind.angle()) - 90.0
	_p.angle_max = _p.angle_min
	_p.scale_amount_min = 0.7
	_p.scale_amount_max = 1.0
	_p.color = Color(0.85, 0.9, 1.0, 0.8)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 2
	t.height = 14
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	_p.texture = t
	_p.emitting = false
	_p.z_index = 6
	add_child(_p)
	if start_wet:
		_begin()
		_level = 1.0
	else:
		_timer = randf_range(dry_min * 0.3, dry_max * 0.5)
	_apply()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		if raining:
			_end()
		else:
			_begin()
	_level = move_toward(_level, 1.0 if raining else 0.0, delta / 6.0)
	_apply()


func _begin() -> void:
	raining = true
	_timer = randf_range(spell_min, spell_max)
	_p.emitting = true
	Audio.ambience("rain", hiss, hiss_db, 6.0)


func _end() -> void:
	raining = false
	_timer = randf_range(dry_min, dry_max)
	Audio.stop_ambience("rain", 6.0)


func _apply() -> void:
	# CPUParticles2D has no amount ratio; fade the drops instead, and stop
	# emitting once dry so nothing is simulated for nothing.
	_p.modulate.a = _level
	if _level <= 0.0 and not raining:
		_p.emitting = false
