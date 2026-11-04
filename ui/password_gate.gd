class_name PasswordGate
extends CanvasLayer
## A board of empty squares that wants a code typed into it.
##
## Built for the Corrupted Grove's lintel — the way through to the Haven — but
## it knows nothing about that: the caller sets `answer`, `length` and the
## wording, adds it to the tree, and awaits `closed(accepted)`. Use it for any
## lock whose key is something the player knows rather than something they
## carry.
##
## Made of the same wood as the pause board (`ui/wood_ui.gd`), and modal in the
## same way: it pauses the tree, so it runs on PROCESS_MODE_ALWAYS, and it
## pushes itself onto the UiStack so Esc and [J] do not reach past it.
##
## The six squares are drawn by hand, but the text under them is a real,
## invisible LineEdit. That is deliberate: the code for this lock lives outside
## the game, so a player is far more likely to paste it than to type it, and a
## LineEdit brings paste, selection, held-key repeat and IME with it. Hand-
## rolled key handling would have none of those.

## Emitted once, as the board goes. `accepted` is false if the player backed
## out, true only if they got it right.
signal closed(accepted: bool)

## The code, compared case-insensitively. Digits and letters only.
@export var answer: String = ""
## How many squares there are. The board will not let you type past it.
@export var length: int = 6
@export var heading: String = "SIX MARKS"
@export var blurb: String = "Six squares cut into the stone, waiting to be filled."
@export var wrong_text: String = "The marks fade. That is not it."
@export var right_text: String = "The marks sink in and stay lit."

const HINT := "Type or paste · Enter to try · Esc to step back"
const BOARD_W := 700.0
const BOARD_H := 480.0
const SLOT := Vector2(72.0, 92.0)
const SLOT_GAP := 14.0
## Only these go in the squares, whatever the keyboard sends.
const ALLOWED := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

var _shaker: Control
var _board: Panel
var _entry: LineEdit
var _slots: Array[Panel] = []
var _marks: Array[Label] = []
var _note: Label
var _caret := 0.0
var _done := false
## Built once, not per frame: _process repaints the squares every tick and a
## fresh StyleBoxFlat each time would churn a dozen objects a frame for a
## board that changes about twice a second.
var _sb_empty: StyleBoxFlat
var _sb_next: StyleBoxFlat
var _sb_filled: StyleBoxFlat
var _sb_lit: StyleBoxFlat
## What _refresh_slots last drew, so it can do nothing when nothing changed.
var _drawn := [-1, false]


func _ready() -> void:
	layer = 160                       # over the pause board, which is 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	UiStack.push("password")
	get_tree().paused = true
	_entry.grab_focus()


func _process(delta: float) -> void:
	# The caret is a pulse on the next empty square rather than a bar, because
	# the squares are carved into wood and a text cursor would read as a form.
	_caret += delta
	_refresh_slots()


# --- entry ------------------------------------------------------------------

func _on_changed(text: String) -> void:
	var clean := ""
	for c in text.to_upper():
		if ALLOWED.contains(c) and clean.length() < length:
			clean += c
	if clean != _entry.text:
		_entry.text = clean
		_entry.caret_column = clean.length()
	_note.text = HINT
	_refresh_slots()


## The Try plank. Separate from the field's own submit so neither has to carry
## an argument it does not want.
func _on_try() -> void:
	_on_submit("")


func _on_submit(_text: String) -> void:
	if _done:
		return
	if _entry.text.length() < length:
		_note.text = "All %d, then." % length
		_shake(6.0)
		return
	if _entry.text == answer.to_upper():
		_accept()
	else:
		_reject()


func _accept() -> void:
	_done = true
	_entry.editable = false
	_note.text = right_text
	Audio.sfx("res://audio/sfx/page_pickup.wav", -4.0, 0.0)
	for slot in _slots:
		slot.add_theme_stylebox_override("panel", _sb_lit)
	# Long enough to read the line and see the squares light, short enough not
	# to feel like it has stopped responding.
	await get_tree().create_timer(1.3).timeout
	_finish(true)


func _reject() -> void:
	_note.text = wrong_text
	Audio.sfx("res://audio/sfx/stone_crumble.wav", -10.0, 0.1)
	_shake(14.0)
	_entry.text = ""
	_refresh_slots()


## Clicking anywhere on the board puts the keys back in the field, so a stray
## click cannot leave the player typing into nothing. Deferred because focus is
## still being handed over when this fires.
func _on_focus_lost() -> void:
	if not _done:
		_entry.call_deferred("grab_focus")


## Back out without answering. The gate stays shut and the caller is told so.
func _cancel() -> void:
	_finish(false)


func _finish(accepted: bool) -> void:
	if not is_inside_tree():
		return
	# Also stops the field grabbing focus back as it is taken out of the tree.
	_done = true
	UiStack.pop("password")
	get_tree().paused = false
	closed.emit(accepted)
	queue_free()


func _shake(px: float) -> void:
	# The board itself is anchored, so its resting `position` is wherever the
	# layout put it — tweening that back to 0 would fling it into the corner.
	# _shaker is full-rect and therefore rests at (0, 0), which is a thing you
	# can safely tween to.
	# Bound to this node, which is PROCESS_MODE_ALWAYS, so it runs while the
	# rest of the tree is stopped.
	var t := create_tween()
	for step in [-px, px * 0.7, -px * 0.4, 0.0]:
		t.tween_property(_shaker, "position:x", step, 0.055)


func _input(event: InputEvent) -> void:
	# Handled here rather than in _unhandled_input: the pause board also
	# listens for Esc and runs while paused, so this has to get there first.
	if _done or not event.is_pressed() or event.is_echo():
		return
	if event.is_action("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()


# --- drawing ----------------------------------------------------------------

func _refresh_slots() -> void:
	if _done:
		return
	var typed := _entry.text
	var at := typed.length()
	var on := fmod(_caret, 1.0) < 0.55
	if _drawn[0] == at and _drawn[1] == on:
		return
	_drawn = [at, on]
	for i in _slots.size():
		_marks[i].text = typed[i] if i < at else ""
		_slots[i].add_theme_stylebox_override("panel",
				_sb_filled if i < at else (_sb_next if i == at and on else _sb_empty))


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.01, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	_shaker = Control.new()
	_shaker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_shaker)

	_board = Panel.new()
	_board.add_theme_stylebox_override("panel", WoodUI.board())
	_board.set_anchors_preset(Control.PRESET_CENTER)
	_board.offset_left = -BOARD_W * 0.5
	_board.offset_right = BOARD_W * 0.5
	_board.offset_top = -BOARD_H * 0.5
	_board.offset_bottom = BOARD_H * 0.5
	_shaker.add_child(_board)

	var bolts := WoodUI.Bolts.new()
	bolts.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.add_child(bolts)

	for l in WoodUI.carved(heading, 42.0, 7.0, 68.0, BOARD_W, WoodUI.BONE, 4.0, 2.0):
		_board.add_child(l)

	var sub := WoodUI.label(blurb, 20, WoodUI.BONE_DIM)
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.offset_left = -BOARD_W * 0.5 + 40
	sub.offset_right = BOARD_W * 0.5 - 40
	sub.offset_top = 112
	sub.offset_bottom = 148
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_board.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(SLOT_GAP))
	row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	var row_w := length * SLOT.x + (length - 1) * SLOT_GAP
	row.offset_left = -row_w * 0.5
	row.offset_right = row_w * 0.5
	row.offset_top = 186
	row.offset_bottom = 186 + SLOT.y
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(row)

	_sb_empty = WoodUI.plank(WoodUI.GRAIN, WoodUI.FRAME)
	_sb_next = WoodUI.plank(WoodUI.GRAIN, WoodUI.BONE_DIM)
	_sb_filled = WoodUI.plank(WoodUI.WOOD_LIT, WoodUI.FRAME)
	_sb_lit = WoodUI.plank(WoodUI.WOOD_LIT, WoodUI.BONE_DIM)

	var face := WoodUI.mono(46.0, 0.0)
	for i in length:
		var slot := Panel.new()
		slot.custom_minimum_size = SLOT
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_stylebox_override("panel", _sb_empty)
		var mark := WoodUI.label("", 46, WoodUI.BONE)
		mark.add_theme_font_override("font", face)
		mark.add_theme_constant_override("outline_size", 6)
		mark.add_theme_color_override("font_outline_color", WoodUI.CARVE)
		mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(mark)
		row.add_child(slot)
		_slots.append(slot)
		_marks.append(mark)

	# The real text field, over the squares and invisible: no background, no
	# caret, no selection tint, and glyphs in a fully transparent colour. The
	# squares above are what the player reads.
	_entry = LineEdit.new()
	_entry.max_length = length
	_entry.flat = true
	_entry.caret_blink = false
	_entry.context_menu_enabled = false
	_entry.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_entry.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_entry.add_theme_color_override("font_color", Color.TRANSPARENT)
	_entry.add_theme_color_override("font_selected_color", Color.TRANSPARENT)
	_entry.add_theme_color_override("caret_color", Color.TRANSPARENT)
	_entry.add_theme_color_override("selection_color", Color.TRANSPARENT)
	_entry.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_entry.offset_left = -row_w * 0.5
	_entry.offset_right = row_w * 0.5
	_entry.offset_top = 186
	_entry.offset_bottom = 186 + SLOT.y
	_entry.text_changed.connect(_on_changed)
	_entry.text_submitted.connect(_on_submit)
	_entry.focus_exited.connect(_on_focus_lost)
	_board.add_child(_entry)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	buttons.set_anchors_preset(Control.PRESET_CENTER_TOP)
	buttons.offset_left = -300
	buttons.offset_right = 300
	buttons.offset_top = 326
	_board.add_child(buttons)
	for b: Button in [WoodUI.button("Try", _on_try),
			WoodUI.button("Step back", _cancel)]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# The field keeps the keyboard; these are for the mouse only, so they
		# must not be able to take focus away from it.
		b.focus_mode = Control.FOCUS_NONE
		buttons.add_child(b)

	_note = WoodUI.label(HINT, 18, WoodUI.BONE_DIM)
	_note.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_note.offset_top = -62
	_note.offset_bottom = -26
	_board.add_child(_note)
