extends PointLight2D
## A pool of light that comes up as the day goes down: a campfire, a lantern
## on the path. Draws nothing by day — it reads the Clock's tint and turns its
## energy up as that darkens, so it only ever shows against the night.
## `always_on` is for places with no sky, like a cave.

@export var radius := 72.0
@export var strength := 1.1
@export var warm := Color(1.0, 0.78, 0.5)
## Flame wobble; 0 for a steady lantern.
@export var flicker := 0.0
@export var always_on := false
## A lantern on its way out: it gutters and goes dark for a moment now and
## then, and sometimes stutters trying to come back.
@export var faulty := false

var _lit := 1.0
var _fault_in := 0.0

var _t := 0.0


func _ready() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.55, Color(1, 1, 1, 0.35))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	texture = tex
	texture_scale = radius * 2.0 / 128.0
	color = warm
	blend_mode = Light2D.BLEND_MODE_ADD
	shadow_enabled = false
	_t = randf() * 10.0
	_update(0.0)


func _process(delta: float) -> void:
	_update(delta)


func _update(delta: float) -> void:
	_t += delta
	var night := 1.0
	if not always_on:
		var tint: Color = Clock.tint()
		var lum := 0.299 * tint.r + 0.587 * tint.g + 0.114 * tint.b
		# White at noon -> 0; the night tint (lum ~0.48) -> 1.
		night = clampf((1.0 - lum) / 0.5, 0.0, 1.0)
	var wobble := 1.0 + flicker * (sin(_t * 11.0) * 0.5 + sin(_t * 23.0 + 1.3) * 0.3 + sin(_t * 5.0) * 0.2)
	if faulty:
		_fault_in -= delta
		if _fault_in <= 0.0:
			if _lit > 0.5:
				# Mostly a clean cut-out; sometimes a dim sputter first.
				_lit = 0.0 if randf() < 0.7 else 0.3
				_fault_in = randf_range(0.08, 0.6)
			else:
				_lit = 1.0
				_fault_in = randf_range(1.0, 4.0)
	energy = strength * night * wobble * _lit
	visible = energy > 0.01
