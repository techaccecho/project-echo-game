class_name WoodUI
extends RefCounted
## The shared look of the game's menus: the palette of art/branding/echo_logo.svg
## and the pieces built from it — carved-plank buttons, the monospace wordmark
## face, grain-and-bolt dressing. The title screen and the pause screen both
## draw from here, so a change to the wood changes both.

# --- the logo's palette, by its role there ---------------------------------
const NIGHT := Color("14100d")      ## ground the sign hangs against
const WOOD := Color("5c4033")       ## the board
const WOOD_LIT := Color("6b4c35")   ## the board, picked out
const GRAIN := Color("3d2817")      ## grain lines and the shallower shadow
const FRAME := Color("8b6f47")      ## the board's edging, and the three dots
const BOLT := Color("3d2817")
const BOLT_RIM := Color("2d1f12")
const CARVE := Color("2d1f12")      ## the deepest shadow under carved letters
const BONE := Color("f4e4c1")       ## the wordmark
const BONE_DIM := Color("d4b896")   ## the tagline
const VINE := Color("4a5d3f")
const LEAF := [Color("6b8e5f"), Color("7fa073"), Color("5d7051")]


## Bold monospace with the logo's letter-spacing. Taken from the system rather
## than bundled: the pack ships no font, and only the menus want a typeface.
static func mono(size: float, spacing: float) -> FontVariation:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray([
		"Menlo", "Consolas", "DejaVu Sans Mono", "Courier New", "monospace"])
	sys.font_weight = 700
	var fv := FontVariation.new()
	fv.base_font = sys
	fv.spacing_glyph = int(spacing)
	fv.variation_embolden = 0.02
	return fv


static func plank(fill: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	return sb


## A plank-cut button. Pointer and keyboard drive the same highlight, so the
## two never disagree about which plank is selected.
static func button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 72)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", BONE_DIM)
	b.add_theme_color_override("font_hover_color", BONE)
	b.add_theme_color_override("font_focus_color", BONE)
	b.add_theme_color_override("font_pressed_color", BONE)
	# A dark outline is what makes the label read as cut into the plank.
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_color_override("font_outline_color", CARVE)
	b.add_theme_stylebox_override("normal", plank(WOOD, GRAIN))
	b.add_theme_stylebox_override("hover", plank(WOOD_LIT, FRAME))
	b.add_theme_stylebox_override("focus", plank(WOOD_LIT, FRAME))
	b.add_theme_stylebox_override("pressed", plank(GRAIN, FRAME))
	b.pressed.connect(pressed)
	b.mouse_entered.connect(b.grab_focus)
	return b


static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A line of the wordmark, carved: two offset shadow copies under a bone face.
## Returns the three labels so the caller can place them; each is anchored to
## the top-centre of its parent and spans `width` around it.
static func carved(text: String, size: float, spacing: float, mid_y: float,
		width: float, face: Color, deep: float, shallow: float) -> Array[Label]:
	var font := mono(size, spacing)
	var layers: Array = [[CARVE, deep]]
	if shallow > 0.0:
		layers.append([GRAIN, shallow])
	layers.append([face, 0.0])
	var out: Array[Label] = []
	for layer in layers:
		var l := label(text, int(size), layer[0])
		l.add_theme_font_override("font", font)
		l.set_anchors_preset(Control.PRESET_CENTER_TOP)
		l.offset_left = -width * 0.5 + layer[1]
		l.offset_right = width * 0.5 + layer[1]
		l.offset_top = mid_y - size + layer[1]
		l.offset_bottom = mid_y + size + layer[1]
		out.append(l)
	return out


## Grain lines and end bolts, drawn over a set of planks. Kept as its own node
## so it sits above the Buttons in the draw order — a Button's stylebox would
## bury anything drawn under it. Add it after the buttons' container.
class PlankDetail extends Control:
	var planks: Array[Button] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for b in planks:
			if not b.is_visible_in_tree():
				continue
			var r := Rect2(b.global_position - global_position, b.size)
			# Three lines with a slight lean, the same figure as the logo's
			# wood-grain pattern.
			for i in 3:
				var x := r.position.x + r.size.x * (0.18 + 0.3 * i)
				draw_line(Vector2(x, r.position.y + 5),
						Vector2(x - 3 + i * 3, r.end.y - 5),
						Color(WoodUI.GRAIN, 0.35), 1.0 + i * 0.5)
			for side in [0.0, 1.0]:
				var c := Vector2(lerpf(r.position.x + 18, r.end.x - 18, side),
						r.position.y + r.size.y * 0.5)
				draw_circle(c, 5.0, WoodUI.BOLT)
				draw_arc(c, 5.0, 0.0, TAU, 16, WoodUI.BOLT_RIM, 2.0)
				draw_circle(c + Vector2(-1, -1), 1.5, Color(WoodUI.WOOD_LIT, 0.5))

	func _process(_delta: float) -> void:
		queue_redraw()
