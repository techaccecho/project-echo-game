extends Node2D
class_name HouseDoor
## The front door of a building you can go into.
##
## Stand on the step and press E to enter; the interior scene puts you back on
## the same step when you leave, via the spawn marker this node carries. Drop
## it on any doorstep and point it at an interior.
##
## A door can also be shut until something has happened: set `required_flag`
## and it stays closed — with a line of its own instead of the doorway — until
## that flag is set. The fishing hut uses this so the rod inside cannot be
## found before the blacksmith has asked for his fish.

## The interior scene this door opens onto.
@export_file("*.tscn") var interior: String = "res://world/blacksmith_interior.tscn"
## Spawn marker inside the interior to arrive on.
@export var interior_spawn: String = "Entrance"
## Name of this door's own marker (the one the interior sends you back to).
## Two doors in one level need two different names.
@export var marker_name: String = "FrontDoor"

@export_group("Locked until")
## World flag that opens this door. Empty means the door is never locked.
@export var required_flag: String = ""
## The .dialogue with the line for trying it too early, and the title in it.
@export_file("*.dialogue") var locked_story: String = ""
@export var locked_title: String = "locked"
## What the prompt says while it is shut.
@export var locked_action: String = "try the door"

@onready var area: InteractionArea = $InteractionArea

var _open_action: String = "enter"


func _ready() -> void:
	area.interact = Callable(self, "_enter")
	$FrontDoor.name = marker_name
	_open_action = area.action_name
	# A flag can be set while the player is stood on the step — he can be sent
	# here by the same conversation that unlocks it — so follow it live.
	if required_flag != "":
		Flags.changed.connect(_on_flag_changed)
	_refresh_prompt()


func _on_flag_changed(flag: String) -> void:
	if flag == required_flag:
		_refresh_prompt()


func _refresh_prompt() -> void:
	area.action_name = _open_action if is_open() else locked_action


func is_open() -> bool:
	return required_flag == "" or Flags.has(required_flag)


func _enter() -> void:
	if not is_open():
		await _say_locked()
		return
	SceneManager.exit_to(interior, interior_spawn)


func _say_locked() -> void:
	if locked_story == "":
		return
	var res = load(locked_story)
	if res == null:
		# A .dialogue only becomes loadable once Dialogue Manager has imported
		# it, so a fresh file is null until the editor has been focused once.
		push_warning("house_door: %s has not been imported yet." % locked_story)
		return
	var player := get_tree().get_first_node_in_group("player")
	DialogueManager.show_dialogue_balloon(res, locked_title, [self, player])
	await DialogueManager.dialogue_ended
