extends Node2D
## Level 3 — the Corrupted Grove. Baked by scratchpad/gen_level3.py; this
## script owns what the bake cannot: the pedestal sequence, the gate, and the
## grove's builder-free odds and ends. Lives inside the shell (game.tscn).
##
## The puzzle: four gem pedestals in the east clearing. Cedric's three pages
## give the order — blue, red, green, purple. Touching them in order lights
## each in turn; a wrong one puts the row out. The full sequence opens the
## gate, which is the hand-off to Level 4 and, until that exists, says so.

const STORY := "res://dialogue/grove.dialogue"
const ORDER := ["blue", "red", "green", "purple"]
const FLAG_OPEN := "level3.gate_open"
## Pedestal tint when lit / dark.
const LIT := Color(1.0, 1.0, 1.0)
const DARK := Color(0.55, 0.5, 0.6)

var _progress := 0
var _busy := false
var _player: CharacterBody2D


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	for p in $Pedestals.get_children():
		var area: InteractionArea = p.get_node("InteractionArea")
		area.interact = Callable(self, "_on_pedestal").bind(p.name)
	$Gate/InteractionArea.interact = Callable(self, "_on_gate")
	$Log/InteractionArea.interact = Callable(self, "_say").bind("log")
	if Flags.has(FLAG_OPEN):
		_open_gate(true)
	else:
		_show_progress()
	# The two hittable trees in each gap have trunk-sized collision that a
	# player can slip past; a blocker closes the whole gap until both are
	# down. Felled trees remember themselves through Flags, so check now too.
	var hits := $HittableTrees.get_children()
	for i in $GateBlockers.get_child_count():
		for tree in hits.slice(i * 2, i * 2 + 2):
			tree.damage_component.max_damage_reached.connect(_check_gate.bind(i))
		_check_gate(i)


func _check_gate(i: int) -> void:
	var hits := $HittableTrees.get_children()
	for tree in hits.slice(i * 2, i * 2 + 2):
		if not tree.max_reached:
			return
	$GateBlockers.get_child(i).set_deferred("disabled", true)


# --- pedestals ---------------------------------------------------------------

func _on_pedestal(name: String) -> void:
	if _busy or Flags.has(FLAG_OPEN):
		if Flags.has(FLAG_OPEN):
			await _say("pedestal_hum")
		return
	_busy = true
	if name == ORDER[_progress]:
		_progress += 1
		_show_progress()
		Audio.sfx("res://audio/sfx/page_pickup.wav", -6.0, 0.15)
		if _progress == ORDER.size():
			await _say("pedestal_done")
			_open_gate(false)
		else:
			await _say("pedestal_hum")
	elif _progress == 0:
		await _say("pedestal_dark")
	else:
		_progress = 0
		_show_progress()
		Audio.sfx("res://audio/sfx/stone_crumble.wav", -12.0, 0.1)
		await _say("pedestal_wrong")
	_busy = false


func _show_progress() -> void:
	for p in $Pedestals.get_children():
		var i := ORDER.find(p.name)
		p.get_node("Sprite2D").modulate = LIT if i < _progress else DARK


# --- the gate ---------------------------------------------------------------

func _open_gate(silent: bool) -> void:
	Flags.set_flag(FLAG_OPEN)
	for p in $Pedestals.get_children():
		p.get_node("Sprite2D").modulate = LIT
	var door: Sprite2D = $Gate/Sprite2D
	if silent:
		door.modulate = Color(0.75, 0.85, 1.0)
		return
	var t := create_tween()
	t.tween_property(door, "modulate", Color(0.75, 0.85, 1.0), 1.2)
	Audio.sfx("res://audio/sfx/stone_crumble.wav", -4.0, 0.0)


func _on_gate() -> void:
	# The way on. Level 4 does not exist yet, so the open gate says as much
	# rather than doing nothing.
	await _say("gate_open" if Flags.has(FLAG_OPEN) else "gate_shut")


# --- helpers ----------------------------------------------------------------

func _say(title: String) -> void:
	var res = load(STORY)
	if res == null:
		push_warning("GameLevel3: %s has not been imported yet." % STORY)
		return
	DialogueManager.show_dialogue_balloon(res, title, [self, _player])
	await DialogueManager.dialogue_ended
