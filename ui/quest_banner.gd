extends CanvasLayer
## Autoload "QuestBanner" — a small plank at the top right naming the current
## quest. The x hides it; the pause menu's "Quest banner" button brings it
## back. The choice is kept in the settings file with the audio switches.

const SETTINGS_FILE := "user://settings.cfg"
## The x: its square, and its distance in from the plank's top and right edges.
const CLOSE_SIZE := 24.0
const CLOSE_INSET := 10.0
## How thick the strike-through is.
const STRIKE_THICKNESS := 3.0

## Whether the player wants it. Whether it is on screen right now also depends
## on being in the game and having a quest left.
var shown := true : set = _set_shown

var _panel: PanelContainer
var _label: Label
var _close: Button
var _text := ""
var _poll := 0.0
## Whether the plank was on screen at the last refresh, and whether a quest is
## being struck through right now. A quest that changes while it is hidden, or
## under a freshly loaded game, is swapped in without ceremony.
var _was_visible := false
var _striking := false


func _ready() -> void:
	# Below the pause menu (150) and bag, above the world.
	layer = 90
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) == OK:
		shown = cfg.get_value("ui", "quest_banner", true)
	_build()
	Flags.changed.connect(func(_f: String) -> void: _refresh())
	EchoLog.collected.connect(func(_f) -> void: _refresh())
	_refresh()


## Flags and fragments cover nearly every change; the poll catches the rest
## (a new game, a loaded save, a scene change) without each needing a hook.
func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		_refresh()


func _refresh() -> void:
	var text: String = Quests.current_text()
	var wanted: bool = shown and not get_tree().current_scene is MainMenu
	if text != _text:
		var old := _text
		_text = text
		if old != "" and _was_visible and wanted and not _striking:
			_strike_then_swap()
	if not _striking:
		_label.text = _text
	# Stay up while the old quest is being crossed out, even if nothing follows.
	_panel.visible = wanted and (_text != "" or _striking)
	_close.visible = _panel.visible
	_was_visible = _panel.visible


## Draw a line through the finished quest like a pen would, hold a moment, then
## let the next one in.
func _strike_then_swap() -> void:
	_striking = true
	var font := _label.get_theme_font("font")
	var size := _label.get_theme_font_size("font_size")
	var width := font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var line := ColorRect.new()
	line.color = WoodUI.BONE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.position = Vector2((_label.size.x - width) * 0.5 - 4.0, _label.size.y * 0.5 - 1.0)
	line.size = Vector2(0.0, STRIKE_THICKNESS)
	_label.add_child(line)

	var t := create_tween()
	t.tween_property(line, "size:x", width + 8.0, 0.45) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.7)
	t.tween_property(_label, "modulate:a", 0.0, 0.2)
	await t.finished

	line.queue_free()
	_striking = false
	_label.text = _text
	_label.modulate.a = 0.0
	_refresh()
	create_tween().tween_property(_label, "modulate:a", 1.0, 0.25)


func _set_shown(value: bool) -> void:
	shown = value
	if _panel:
		_refresh()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("ui", "quest_banner", shown)
	cfg.save(SETTINGS_FILE)


func _build() -> void:
	_panel = PanelContainer.new()
	var sb := WoodUI.plank(WoodUI.WOOD, WoodUI.FRAME)
	sb.content_margin_left = 14
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# Directly under the clock plank (ClockHud: y 24-70, 28px in from the edge),
	# the same width.
	_panel.custom_minimum_size = Vector2(352, 0)
	_panel.offset_top = 80
	_panel.offset_right = -28
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_panel.add_child(row)

	var col := VBoxContainer.new()
	row.add_child(col)
	col.add_child(WoodUI.label("QUEST", 14, WoodUI.FRAME))
	_label = WoodUI.label("", 22, WoodUI.BONE)
	col.add_child(_label)

	# The x lives in the plank's top-right corner, but the row keeps an
	# invisible one the same size so the text sits exactly where it did.
	var spacer := _close_button()
	spacer.modulate.a = 0.0
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	_close = _close_button()
	_close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_close.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# A square with no padding of its own, inset the same from the top and the
	# right of the plank.
	for state in ["normal", "hover", "pressed", "focus"]:
		_close.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_close.custom_minimum_size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	_close.offset_top = _panel.offset_top + CLOSE_INSET
	_close.offset_right = _panel.offset_right - CLOSE_INSET
	_close.pressed.connect(func() -> void: shown = false)
	add_child(_close)


func _close_button() -> Button:
	var close := Button.new()
	close.text = "x"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.tooltip_text = "Hide (bring back from the pause menu)"
	close.add_theme_font_size_override("font_size", 20)
	close.add_theme_color_override("font_color", WoodUI.BONE_DIM)
	close.add_theme_color_override("font_hover_color", WoodUI.BONE)
	return close
