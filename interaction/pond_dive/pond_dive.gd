extends CanvasLayer
class_name PondDive
## The pond in the forest, seen from directly above and close to.
##
## Casting here does not play the river's letter drill. The view drops into the
## water, the bait sinks through a stretch of weed and stone, and the player
## steers it left and right on its way down. Come to rest beside the key on the
## bed and it comes up on the line.
##
## Nothing here can be lost: a miss is a miss and the next cast starts over.
## The pond is a beat, not a wall across the road.
##
## Built in code rather than authored, like SeaLife and the shoreline: the bed
## is scattered fresh every cast, so the second attempt is not the first one
## memorised.

## The bed, in pond pixels: as wide as the window, several windows deep.
const BED := Vector2i(160, 440)
## What is on screen at once.
const VIEW := Vector2i(160, 200)
## Screen pixels per pond pixel.
const ZOOM := 4

@export_group("Feel")
## How fast the bait sinks, in pond pixels a second. The bed is 440 deep, so
## this sets the length of the whole descent.
@export var sink_speed: float = 62.0
## How fast it can be steered across. Well above the sink speed, or the bed is
## a lottery rather than a line to pick.
@export var steer_speed: float = 78.0
## How long weed holds the bait, and how far it shoves it off true.
@export var snag_stall: float = 0.35
@export var snag_push: float = 9.0
## How close to the key counts as hooking it.
@export var catch_radius: float = 13.0

@export_group("Dressing")
@export var weed_count: int = 14
@export var fish_count: int = 5
@export var bubble_count: int = 7

const TEX_PROPS := "res://art/Farm RPG - Tiny Asset Pack - (All in One)/Farm and Tileset/Props/Spring/props water.png"
const TEX_STONES := "res://art/Farm RPG - Tiny Asset Pack - (All in One)/Farm and Tileset/Props/Spring/Stones.png"
const TEX_BUBBLES := "res://art/Farm RPG - Tiny Asset Pack - (All in One)/Farm and Tileset/Fish/bubbles.png"
const TEX_FISH := "res://art/Farm RPG - Tiny Asset Pack - (All in One)/Farm and Tileset/Fish/Fish point small.png"
const TEX_BAIT := "res://art/Farm RPG - Tiny Asset Pack - (All in One)/Icons/Fish/Worm bait.png"
const TEX_KEY := "res://art/Farm RPG - Tiny Asset Pack - (All in One)/UI/Inventory/key-white.png"
const TEX_WATER := "res://art/Farm RPG - Tiny Asset Pack - (All in One)/Farm and Tileset/Tileset/Water tile.png"

## Obstacles, as regions of TEX_PROPS: a lily pad, a clump of reeds, a stone.
const WEED_REGIONS := [Rect2(48, 0, 16, 16), Rect2(144, 0, 16, 16), Rect2(96, 64, 16, 16)]

var _world: Node2D
var _clip: Control
var _bait: Sprite2D
var _line: Line2D
var _cast_x := 0.0
var _key: AnimatedSprite2D
var _title: Label
var _weeds: Array[Sprite2D] = []

var _depth := 0.0
var _stall := 0.0
var _running := false
var _hooked := false


func _ready() -> void:
	layer = 60
	_build()


# --- the cast ---------------------------------------------------------------

## Drop into the pond. Returns true if the key came up on the line. Await it.
func play() -> bool:
	_scatter()
	_cast_x = BED.x * 0.5
	_bait.position = Vector2(_cast_x, 6)
	_draw_line()
	_depth = 0.0
	_stall = 0.0
	_hooked = false
	_title.text = "A  D   to steer"
	await _fade(1.0)
	_running = true
	while _running:
		await get_tree().process_frame
	await _settle()
	await _fade(0.0)
	return _hooked


func _process(delta: float) -> void:
	if not _running:
		return
	if _stall > 0.0:
		_stall -= delta
	else:
		_depth += sink_speed * delta
		var steer := Input.get_action_strength("right") - Input.get_action_strength("left")
		_bait.position.x = clampf(_bait.position.x + steer * steer_speed * delta, 8.0, BED.x - 8.0)
	_bait.position.y = 6.0 + _depth
	_draw_line()
	_snag()
	# The window follows the bait down, stopping at the bed.
	var top := clampf(_bait.position.y - VIEW.y * 0.45, 0.0, float(BED.y - VIEW.y))
	_world.position.y = -top * ZOOM
	if _bait.position.y >= BED.y - 14.0:
		_running = false


## Line from the surface down to the bait, bowed a little so it reads as line
## rather than wire. It enters where the rod put it in and the bait swings
## under it, so steering visibly drags against the cast.
func _draw_line() -> void:
	var from := Vector2(_cast_x, -2.0)
	var to := _bait.position
	var bow: float = (from.x - to.x) * 0.16
	var pts := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		var p := from.lerp(to, t)
		p.x += sin(t * PI) * bow
		pts.append(p)
	_line.points = pts


## Weed and stone hold the line and shove it off true.
func _snag() -> void:
	if _stall > 0.0:
		return
	for w in _weeds:
		if _bait.position.distance_to(w.position) < 11.0:
			_stall = snag_stall
			var away: float = signf(_bait.position.x - w.position.x)
			if away == 0.0:
				away = 1.0
			_bait.position.x = clampf(_bait.position.x + away * snag_push, 8.0, BED.x - 8.0)
			var t := w.create_tween()
			t.tween_property(w, "modulate", Color(1.4, 1.4, 1.4), 0.08)
			t.tween_property(w, "modulate", Color.WHITE, 0.25)
			return


## Did it come to rest by the key?
func _settle() -> void:
	_hooked = _bait.position.distance_to(_key.position) <= catch_radius
	if _hooked:
		_title.text = "something heavy"
		var t := create_tween()
		t.tween_property(_key, "position", _bait.position, 0.25)
		t.parallel().tween_property(_key, "scale", Vector2(1.25, 1.25), 0.25)
		await t.finished
		var up := create_tween().set_parallel()
		up.tween_property(_key, "position:y", _key.position.y - 30.0, 0.5)
		up.tween_property(_bait, "position:y", _bait.position.y - 30.0, 0.5)
		while up.is_running():
			_draw_line()
			await get_tree().process_frame
	else:
		_title.text = "weed. nothing but weed"
		await get_tree().create_timer(0.9).timeout


# --- building it ------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# The window into the water, held in the middle of the screen.
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	_clip = Control.new()
	_clip.clip_contents = true
	_clip.custom_minimum_size = Vector2(VIEW) * ZOOM
	_clip.size = Vector2(VIEW) * ZOOM
	_clip.set_anchors_preset(Control.PRESET_CENTER)
	_clip.position = -_clip.size * 0.5
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_clip)

	var edge := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0.85, 0.53, 0.30)
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 6
	edge.add_theme_stylebox_override("panel", style)
	edge.size = _clip.size + Vector2(8, 8)
	edge.set_anchors_preset(Control.PRESET_CENTER)
	edge.position = -edge.size * 0.5
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(edge)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.93, 0.87, 0.75))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size = Vector2(_clip.size.x, 30)
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.position = Vector2(-_clip.size.x * 0.5, _clip.size.y * 0.5 + 14)
	holder.add_child(_title)

	_world = Node2D.new()
	_world.scale = Vector2(ZOOM, ZOOM)
	_clip.add_child(_world)

	_build_bed()

	_key = _animated(TEX_KEY, 32, 12, 7.0)
	_world.add_child(_key)

	_line = Line2D.new()
	_line.width = 1.0
	_line.default_color = Color(0.92, 0.96, 1.0, 0.7)
	_line.z_index = 3
	_world.add_child(_line)

	_bait = Sprite2D.new()
	_bait.texture = _atlas(TEX_BAIT, Rect2(0, 0, 16, 16))
	_bait.z_index = 4
	_world.add_child(_bait)

	visible = false


## Still water, darkening with depth, so the bed feels below rather than beside.
func _build_bed() -> void:
	var water := load(TEX_WATER) as Texture2D
	var img := water.get_image()
	if img.is_compressed():
		img.decompress()
	var shallow := img.get_pixel(int(img.get_width() * 0.5), int(img.get_height() * 0.5))
	for i in 11:
		var band := ColorRect.new()
		band.color = shallow.darkened(float(i) / 16.0)
		band.position = Vector2(0, i * (BED.y / 11.0))
		band.size = Vector2(BED.x, BED.y / 11.0 + 1)
		band.z_index = -10
		_world.add_child(band)


## Weed, fish and bubbles, laid out fresh for this cast.
func _scatter() -> void:
	for w in _weeds:
		w.queue_free()
	_weeds.clear()
	for n in _world.get_children():
		if n.has_meta("drift"):
			n.queue_free()

	# Obstacles, spread down the bed and never right against the walls.
	var lanes := BED.y - 90
	for i in weed_count:
		var s := Sprite2D.new()
		s.texture = _atlas(TEX_PROPS, WEED_REGIONS[randi() % WEED_REGIONS.size()])
		s.position = Vector2(randf_range(14.0, BED.x - 14.0),
				50.0 + lanes * (float(i) + randf_range(-0.3, 0.3)) / weed_count)
		s.z_index = 1
		_world.add_child(s)
		_weeds.append(s)

	for i in fish_count:
		var f := _animated(TEX_FISH, 16, 11, 4.0)
		f.position = Vector2(randf_range(16.0, BED.x - 16.0), randf_range(40.0, BED.y - 40.0))
		f.z_index = 2
		f.modulate.a = 0.75
		f.set_meta("drift", true)
		_world.add_child(f)
		_drift(f, randf_range(2.6, 4.4))

	for i in bubble_count:
		var b := _animated(TEX_BUBBLES, 16, 7, 6.0)
		b.position = Vector2(randf_range(10.0, BED.x - 10.0), randf_range(30.0, BED.y - 20.0))
		b.z_index = 3
		b.modulate.a = 0.6
		b.set_meta("drift", true)
		_world.add_child(b)

	# The key, on the bed, off to one side so the descent has to be steered.
	_key.position = Vector2(randf_range(26.0, BED.x - 26.0), BED.y - 26.0)
	_key.scale = Vector2.ONE
	_key.z_index = 2


## Fish wander their patch rather than sitting still.
func _drift(node: Node2D, seconds: float) -> void:
	var home := node.position
	var t := node.create_tween().set_loops()
	for i in 3:
		var to := home + Vector2(randf_range(-22.0, 22.0), randf_range(-12.0, 12.0))
		to.x = clampf(to.x, 12.0, BED.x - 12.0)
		t.tween_property(node, "position", to, seconds).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "position", home, seconds).set_trans(Tween.TRANS_SINE)


# --- odds and ends ----------------------------------------------------------

func _atlas(path: String, region: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load(path)
	a.region = region
	return a


## One strip of `frames` square cells as a looping AnimatedSprite2D.
func _animated(path: String, size: int, frames: int, fps: float) -> AnimatedSprite2D:
	var sf := SpriteFrames.new()
	sf.set_animation_speed(&"default", fps)
	sf.set_animation_loop(&"default", true)
	for i in frames:
		sf.add_frame(&"default", _atlas(path, Rect2(i * size, 0, size, size)))
	var a := AnimatedSprite2D.new()
	a.sprite_frames = sf
	a.frame = randi() % frames
	a.play()
	return a


func _fade(to: float) -> void:
	visible = true
	var start := 0.0 if to > 0.5 else 1.0
	for c in get_children():
		(c as CanvasItem).modulate.a = start
	var t := create_tween().set_parallel()
	for c in get_children():
		t.tween_property(c, "modulate:a", to, 0.28)
	await t.finished
	visible = to > 0.5
