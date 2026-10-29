extends CanvasLayer
## Autoload "LampHud" — a plank in the bottom-left corner showing how much oil is left in
## the torch: the torch (burning or not), a bar, the percentage (or OFF), and how many flasks he is
## carrying. Shown once the torch is in his bag. Lamp's short lines ("The torch
## is already soaked.") appear just above it for a moment and fade.

const BAR_FILL := Color("f0b048")
const BAR_LOW := Color("d8503a")
const BAR_BACK := Color("2d1f12")
## How long a message stays before it starts to fade.
const MESSAGE_HOLD := 2.2
const MESSAGE_FADE := 0.6
## The torch's icon while it burns; out, it is the item's own (unlit) icon.
const LIT_ICON_REGION := Rect2(48, 9, 16, 36)

var _root: Control
var _bar: Control
var _pct: Label
var _flasks: Label
var _lamp_icon: TextureRect
var _message: Label
var _message_tween: Tween
var _t := 0.0
var _lit_icon: AtlasTexture


func _ready() -> void:
	layer = 40
	_root = Control.new()
	# Bottom left, level with the hotbar: the top right is the clock and the
	# quest banner, whose height changes with the quest.
	_root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_root.offset_left = 28
	_root.offset_right = 380
	_root.offset_top = -86
	_root.offset_bottom = -40
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var plank := Panel.new()
	plank.add_theme_stylebox_override("panel", WoodUI.plank(WoodUI.WOOD, WoodUI.GRAIN))
	plank.set_anchors_preset(Control.PRESET_FULL_RECT)
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(plank)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(row)

	_lamp_icon = _icon(Lamp.LAMP_ITEM.texture)
	var unlit := Lamp.LAMP_ITEM.texture as AtlasTexture
	if unlit != null:
		_lit_icon = AtlasTexture.new()
		_lit_icon.atlas = unlit.atlas
		_lit_icon.region = LIT_ICON_REGION
	row.add_child(_lamp_icon)

	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(150, 16)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	row.add_child(_bar)

	_pct = _label("", 18)
	_pct.custom_minimum_size = Vector2(64, 0)
	row.add_child(_pct)

	row.add_child(_icon(Lamp.OIL_ITEM.texture))
	_flasks = _label("", 18)
	row.add_child(_flasks)

	_message = _label("", 18)
	_message.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# Just above the plank.
	_message.offset_top = -34
	_message.offset_bottom = -6
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_message.modulate.a = 0.0
	_root.add_child(_message)

	Lamp.message.connect(_show_message)


func _process(delta: float) -> void:
	_t += delta
	var show: bool = Clock.running and Lamp.has_lamp() \
			and not (get_tree().current_scene is MainMenu) and not PauseMenu.is_open
	_root.visible = show
	if not show:
		return
	_pct.text = "%d%%" % ceili(Lamp.fuel) if Lamp.on else "OFF [L]"
	_pct.add_theme_color_override("font_color",
			WoodUI.BONE if Lamp.on else WoodUI.BONE_DIM)
	var lit := Lamp.is_lit()
	_lamp_icon.texture = _lit_icon if lit and _lit_icon != null else Lamp.LAMP_ITEM.texture
	_lamp_icon.modulate = Color.WHITE if lit else Color(0.75, 0.7, 0.65)
	_flasks.text = "x%d" % Lamp.oil_count()
	_bar.queue_redraw()


func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_rect(r, BAR_BACK)
	var f := clampf(Lamp.fraction(), 0.0, 1.0)
	var fill := BAR_FILL
	if Lamp.is_low():
		# Pulse when low, so it is noticed out of the corner of the eye.
		fill = BAR_LOW.lerp(BAR_FILL, 0.5 + 0.5 * sin(_t * 8.0)) if Lamp.on else BAR_LOW
	if not Lamp.on:
		fill = fill.darkened(0.35)
	var inner := r.grow(-2)
	inner.size.x *= f
	_bar.draw_rect(inner, fill)
	# A notch at the low mark.
	var x := 2.0 + (r.size.x - 4.0) * Lamp.LOW / Lamp.CAPACITY
	_bar.draw_line(Vector2(x, 1), Vector2(x, r.size.y - 1), WoodUI.FRAME, 1.0)
	_bar.draw_rect(r, WoodUI.FRAME, false, 1.0)


func _show_message(text: String) -> void:
	_message.text = text
	if _message_tween != null:
		_message_tween.kill()
	_message.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(MESSAGE_HOLD)
	_message_tween.tween_property(_message, "modulate:a", 0.0, MESSAGE_FADE)


func _icon(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(28, 28)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _label(text: String, size: int) -> Label:
	var l := WoodUI.label(text, size, WoodUI.BONE)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", WoodUI.CARVE)
	return l
