extends CanvasLayer
## The in-game menu (autoload "PauseMenu"). Esc opens it anywhere in the game,
## freezes the world, and offers resume / music and sound toggles / save /
## quit to title. The
## title screen's Settings button opens the same board in a trimmed form.
##
## An autoload, like the journal, because the game runs several different
## roots — Level 1, the shell, house interiors, the title — and the menu has
## to exist in all of them. Built from the same wood as the title screen.

const TITLE_SCENE := "res://ui/main_menu.tscn"
const SETTINGS_FILE := "user://settings.cfg"
const HINT_PAUSED := "Esc to resume"
const HINT_SETTINGS := "Esc to go back"

var is_open := false
## Music is its own bus. "Sound" is everything else that is not music: the
## SFX bus and the Ambience bus together, since to the player wind, sea and
## footsteps are all just "the sound".
var music_muted := false : set = _set_music_muted
var sound_muted := false : set = _set_sound_muted

var _root: Control
var _title: Array[Label] = []
var _buttons: Array[Button] = []
var _resume: Button
var _music: Button
var _sound: Button
var _save: Button
var _quit: Button
var _back: Button
var _hint: Label
var _board: Panel
var _settings_only := false
var _busy := false


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_build()
	_root.visible = false


# --- opening and closing ----------------------------------------------------

func open() -> void:
	_show(false)


## The title screen's Settings: the same board, without resume/save/quit, and
## nothing to pause.
func open_settings() -> void:
	_show(true)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	if not _settings_only:
		get_tree().paused = false


func _show(settings_only: bool) -> void:
	if is_open or _busy:
		return
	is_open = true
	_settings_only = settings_only
	for l in _title:
		l.text = "SETTINGS" if settings_only else "PAUSED"
	_resume.visible = not settings_only
	_save.visible = not settings_only
	_quit.visible = not settings_only
	_back.visible = settings_only
	_hint.text = HINT_SETTINGS if settings_only else HINT_PAUSED
	_refresh_labels()
	# A shorter board when there are only two planks on it.
	var h := BOARD_H_SETTINGS if settings_only else BOARD_H
	_board.offset_top = -h * 0.5
	_board.offset_bottom = h * 0.5
	_ring_focus()
	if not settings_only:
		get_tree().paused = true
	_root.visible = true
	(_back if settings_only else _resume).grab_focus()


## Arrow keys and Tab walk the whole viewport's focusable controls, which on
## the title screen would step off the board onto the planks behind it. Tie
## the visible buttons into a ring so navigation stays on the board.
func _ring_focus() -> void:
	var shown: Array[Button] = []
	for b in _buttons:
		if b.visible:
			shown.append(b)
	for i in shown.size():
		var prev := shown[wrapi(i - 1, 0, shown.size())]
		var next := shown[wrapi(i + 1, 0, shown.size())]
		shown[i].focus_neighbor_top = shown[i].get_path_to(prev)
		shown[i].focus_neighbor_bottom = shown[i].get_path_to(next)
		shown[i].focus_previous = shown[i].get_path_to(prev)
		shown[i].focus_next = shown[i].get_path_to(next)
		shown[i].focus_neighbor_left = shown[i].get_path_to(shown[i])
		shown[i].focus_neighbor_right = shown[i].get_path_to(shown[i])


## Whether Esc may open the menu right now: not on the title screen, and not
## while something else (a cutscene) has the tree paused.
func _can_open() -> bool:
	if get_tree().current_scene is MainMenu:
		return false
	return not get_tree().paused


# --- actions ----------------------------------------------------------------

func _on_music() -> void:
	music_muted = not music_muted
	_refresh_labels()


func _on_sound() -> void:
	sound_muted = not sound_muted
	_refresh_labels()


func _on_save() -> void:
	if not SaveGame.can_save():
		_flash("Not now — wait until you're on your feet.")
	elif SaveGame.save():
		_flash("Saved.")
	else:
		_flash("Could not save.")


func _flash(text: String) -> void:
	_hint.text = text
	var t := create_tween()
	t.tween_interval(2.0)
	t.tween_callback(func() -> void:
		_hint.text = HINT_SETTINGS if _settings_only else HINT_PAUSED)


func _on_quit() -> void:
	if _busy:
		return
	_busy = true
	_root.visible = false
	is_open = false
	await SceneManager.quit_to_title(TITLE_SCENE)
	_busy = false


func _set_music_muted(value: bool) -> void:
	music_muted = value
	_mute_bus("Music", value)
	_save_settings()


func _set_sound_muted(value: bool) -> void:
	sound_muted = value
	_mute_bus("SFX", value)
	_mute_bus("Ambience", value)
	_save_settings()


func _mute_bus(bus: String, value: bool) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_mute(i, value)


func _refresh_labels() -> void:
	if _music:
		_music.text = "Music: off" if music_muted else "Music: on"
	if _sound:
		_sound.text = "Sound: off" if sound_muted else "Sound: on"


# --- settings on disk -------------------------------------------------------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var cfg_ok := cfg.load(SETTINGS_FILE) == OK
	music_muted = cfg_ok and cfg.get_value("audio", "music_muted", false)
	sound_muted = cfg_ok and cfg.get_value("audio", "sound_muted", false)
	# The first version had one master switch; a file from then is left as it
	# was except for that key, which nothing reads any more.
	if cfg_ok and cfg.has_section_key("audio", "muted"):
		cfg.erase_section_key("audio", "muted")
		cfg.save(SETTINGS_FILE)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("audio", "music_muted", music_muted)
	cfg.set_value("audio", "sound_muted", sound_muted)
	cfg.save(SETTINGS_FILE)


# --- input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("ui_cancel"):
		if is_open:
			close()
		elif _can_open():
			open()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	# The game moves on WASD and acts on E; the menu answers to the same keys.
	if event.is_action("up"):
		_step_focus(-1)
	elif event.is_action("down"):
		_step_focus(1)
	elif event.is_action("interact"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused:
			focused.emit_signal("pressed")
	else:
		return
	get_viewport().set_input_as_handled()


func _step_focus(dir: int) -> void:
	var shown: Array[Button] = []
	for b in _buttons:
		if b.visible:
			shown.append(b)
	if shown.is_empty():
		return
	var at := shown.find(get_viewport().gui_get_focus_owner())
	shown[wrapi(at + dir, 0, shown.size())].grab_focus()


# --- construction -----------------------------------------------------------

const BOARD_W := 560.0
const BOARD_H := 680.0
const BOARD_H_SETTINGS := 500.0

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Dim the game rather than hide it: you are still in the room, just
	# stopped.
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.01, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var board := Panel.new()
	_board = board
	var sb := StyleBoxFlat.new()
	sb.bg_color = WoodUI.WOOD
	sb.border_color = WoodUI.FRAME
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 8)
	board.add_theme_stylebox_override("panel", sb)
	board.set_anchors_preset(Control.PRESET_CENTER)
	board.offset_left = -BOARD_W * 0.5
	board.offset_right = BOARD_W * 0.5
	board.offset_top = -BOARD_H * 0.5
	board.offset_bottom = BOARD_H * 0.5
	_root.add_child(board)

	var bolts := Bolts.new()
	bolts.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.add_child(bolts)

	_title = WoodUI.carved("PAUSED", 48.0, 8.0, 74.0, BOARD_W, WoodUI.BONE, 4.0, 2.0)
	for l in _title:
		board.add_child(l)

	var menu := VBoxContainer.new()
	menu.set_anchors_preset(Control.PRESET_CENTER_TOP)
	menu.offset_left = -200
	menu.offset_right = 200
	menu.offset_top = 140
	menu.add_theme_constant_override("separation", 16)
	board.add_child(menu)

	_resume = _button("Resume", close)
	_music = _button("Music: on", _on_music)
	_sound = _button("Sound: on", _on_sound)
	_save = _button("Save game", _on_save)
	_quit = _button("Quit to title", _on_quit)
	_back = _button("Back", close)
	for b in [_resume, _music, _sound, _save, _quit, _back]:
		menu.add_child(b)

	var detail := WoodUI.PlankDetail.new()
	detail.planks = _buttons
	detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.add_child(detail)

	_hint = WoodUI.label(HINT_PAUSED, 18, WoodUI.BONE_DIM)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -64
	_hint.offset_bottom = -28
	board.add_child(_hint)


func _button(text: String, pressed: Callable) -> Button:
	var b := WoodUI.button(text, pressed)
	_buttons.append(b)
	return b


## The four corner bolts of the logo's signboard.
class Bolts extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for cx in [22.0, size.x - 22.0]:
			for cy in [22.0, size.y - 22.0]:
				var c := Vector2(cx, cy)
				draw_circle(c, 7.0, WoodUI.BOLT)
				draw_arc(c, 7.0, 0.0, TAU, 20, WoodUI.BOLT_RIM, 2.5)
				draw_circle(c + Vector2(-1.5, -1.5), 2.0, Color(WoodUI.WOOD_LIT, 0.5))
