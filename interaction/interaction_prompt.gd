extends Node2D
class_name InteractionPrompt
## The little "E · sit" tag that floats over whatever the player can use.
##
## Drawn by hand in world space so it stays pixel-crisp at the game's zoom:
## a keycap with the key, then the verb, on a slip of the same wood the
## menus are cut from. Sits above everything (absolute z), because the props
## it labels are y-sorted at z 5 and used to draw over it.

const WOOD := Color("5c4033")
const FRAME := Color("8b6f47")
const CARVE := Color("2d1f12")
const BONE := Color("f4e4c1")
const BONE_DIM := Color("d4b896")

## Sizes in world pixels; the drawing multiplies them by the camera zoom so
## the text is rasterised at screen resolution.
const FONT_PX := 6
const PAD := 3
const CAP := 8          ## keycap square

var _key := "E"
var _verb := "interact"
var _font: Font
var _t := 0.0
var _alpha := 0.0
var _target_alpha := 0.0


func _ready() -> void:
	z_index = 100
	z_as_relative = false
	_font = ThemeDB.fallback_font
	visible = false


func set_prompt(key: String, verb: String) -> void:
	if key != _key or verb != _verb:
		_key = key
		_verb = verb
		queue_redraw()


func show_at(world_pos: Vector2) -> void:
	global_position = (world_pos + Vector2(0, -26)).round()
	if not visible:
		_alpha = 0.0
		_t = 0.0
	visible = true
	_target_alpha = 1.0


func hide_prompt() -> void:
	_target_alpha = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_alpha = move_toward(_alpha, _target_alpha, delta * 8.0)
	if _alpha <= 0.0 and _target_alpha <= 0.0:
		visible = false
		return
	queue_redraw()


func _draw() -> void:
	# Drawn at screen resolution: the camera zooms the world 3-4x, and text
	# rasterised at 6px then scaled up is mush. So everything below is in
	# screen pixels, and the whole drawing is scaled back down by the zoom.
	var cam := get_viewport().get_camera_2d()
	var z: float = cam.zoom.x if cam else 3.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 / z, 1.0 / z))
	var fpx := int(FONT_PX * z)
	var pad := PAD * z
	var cap_px := CAP * z
	var verb_w := _font.get_string_size(_verb, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x
	var w := pad + cap_px + pad + verb_w + pad
	var h := cap_px + pad * 2
	# A slow bob, so the eye finds it.
	var bob := roundf(sin(_t * 3.2) * 1.0) * z
	var box := Rect2(Vector2(-w * 0.5, -h + bob).round(), Vector2(w, h).round())
	var a := _alpha
	draw_rect(box, Color(CARVE, 0.9 * a))                                   # edge
	draw_rect(box.grow(-z), Color(WOOD, a))
	# keycap
	var cap := Rect2(box.position + Vector2(pad, pad), Vector2(cap_px, cap_px))
	draw_rect(cap, Color(BONE, a))
	draw_rect(cap.grow(-z), Color(BONE_DIM, a))
	var kw := _font.get_string_size(_key, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x
	draw_string(_font, cap.position + Vector2((cap_px - kw) * 0.5, cap_px - 1.5 * z).round(), _key,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fpx, Color(CARVE, a))
	# verb, with a one-pixel shadow so it reads as cut in
	var tx := cap.end.x + pad
	var ty := box.position.y + h - pad - 1.5 * z
	draw_string(_font, Vector2(tx + 1, ty + 1).round(), _verb, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx, Color(CARVE, a))
	draw_string(_font, Vector2(tx, ty).round(), _verb, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx, Color(BONE, a))
	# tiny tail pointing at the thing
	var tip := Vector2(0, bob)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-2 * z, 0), tip + Vector2(2 * z, 0), tip + Vector2(0, 2 * z)]), Color(CARVE, 0.9 * a))
