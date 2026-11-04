extends Node2D
## The drifting lights of the Haven: slow, warm, and rising.
##
## Built in code for the same reason GloomWeather is — every knob lives on the
## node, so there is no separate particle resource to drift out of step with
## the level. Two emitters: a broad, faint field across the whole plain, and a
## sparser set of brighter, larger motes that read as the near ones.

@export var area_size: Vector2 = Vector2(1088, 768)
@export var area_center: Vector2 = Vector2(544, 384)
@export_range(0, 300) var count: int = 90
## The warm half of "pale lavender and gold".
@export var color: Color = Color(1.0, 0.93, 0.74, 0.5)


func _ready() -> void:
	add_child(_field(count, 2.4, 11.0, Color(color, color.a * 0.55), 17))
	add_child(_field(count / 4, 5.0, 16.0, color, 19))


func _field(amount: int, size: float, life: float, tint: Color,
		z: int) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = maxi(1, amount)
	p.lifetime = life
	# Run the sim forward before the first frame, so the level opens with the
	# motes already in the air instead of spawning them in a visible wave.
	p.preprocess = life
	p.local_coords = false
	p.z_index = z
	p.position = area_center
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area_size * 0.5
	p.texture = _dot(size)
	p.direction = Vector2.UP
	p.spread = 34.0
	p.gravity = Vector2(0.0, -2.5)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 11.0
	p.damping_min = 0.0
	p.damping_max = 1.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color = tint
	# Fade in and out rather than popping, so nothing has a visible birth.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.add_point(0.75, Color(1, 1, 1, 0.85))
	p.color_ramp = ramp
	return p


## A soft round dot, bright in the middle.
func _dot(size: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.4, Color(1, 1, 1, 0.8))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = int(size * 4.0)
	t.height = int(size * 4.0)
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
