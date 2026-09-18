extends CanvasLayer
## Autoload "ClockHud" — a small plank in the top-right corner:
## "Day 1 · Morning · 7:30".
## Shown only while a game is running; the title screen and pause board hide it.

var _root: Control
var _label: Label


func _ready() -> void:
	layer = 40
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_root.offset_left = -380
	_root.offset_right = -28
	_root.offset_top = 24
	_root.offset_bottom = 70
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var plank := Panel.new()
	plank.add_theme_stylebox_override("panel", WoodUI.plank(WoodUI.WOOD, WoodUI.GRAIN))
	plank.set_anchors_preset(Control.PRESET_FULL_RECT)
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(plank)

	_label = WoodUI.label("", 20, WoodUI.BONE)
	_label.add_theme_constant_override("outline_size", 5)
	_label.add_theme_color_override("font_outline_color", WoodUI.CARVE)
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_label)


func _process(_delta: float) -> void:
	var show: bool = Clock.running and not (get_tree().current_scene is MainMenu) \
			and not PauseMenu.is_open
	_root.visible = show
	if show:
		_label.text = "Day %d  ·  %s  ·  %s" % [Clock.day, Clock.phase_name(), Clock.time_text()]
