class_name FishingSpot
extends Node2D
## A stretch of water worth casting into.
##
## Gated on holding the rod — the highlighted hotbar slot, not just somewhere in
## the bag — the same way the rubble wall is gated on the axe: without it the
## prompt drops to "look at the water" and the player gets a line instead of the
## minigame. The rod is in the abandoned hut, which is itself shut until the
## blacksmith has asked for his fish — so the order of the opening act holds
## without any spot needing to know about the quest.

@export var fish_pool: Array[InvItem] = []
@export var min_wait_time: float = 0.8
@export var max_wait_time: float = 1.8
## Item the player must be carrying to fish here. Leave null to allow anyone.
@export var required_item: InvItem
## Line shown when they have nothing to fish with.
@export var empty_handed_title: String = "no_rod"

@onready var interaction_area: InteractionArea = $InteractionArea

var dialogue_resource = load("res://dialogue/fishing_spot.dialogue")
var player: CharacterBody2D
var busy: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	interaction_area.interact = Callable(self, "_on_interact")
	# The prompt has to change the moment the rod comes out, not on the next
	# cast — the player may well walk here holding it before touching anything
	# else, and may wheel it away again while standing on the bank.
	if player != null and player.inv != null:
		player.inv.update.connect(_refresh_prompt)
		player.inv.selection_changed.connect(_refresh_prompt)
	_refresh_prompt()

## The prompt doubles as the hint: "fish" only shows once you have the rod.
func _refresh_prompt() -> void:
	interaction_area.action_name = "fish" if _player_has_rod() else "look at the water"

func _player_has_rod() -> bool:
	if required_item == null:
		return true
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	return player != null and player.inv != null and player.inv.holding(required_item)

func _on_interact() -> void:
	if busy or player == null:
		return
	if not _player_has_rod():
		_refresh_prompt()
		await _say(empty_handed_title)
		return
	busy = true
	var face_direction = (global_position - player.global_position).normalized()
	await player.catch_fish(fish_pool, face_direction, min_wait_time, max_wait_time)
	busy = false
	_refresh_prompt()

func _say(title: String) -> void:
	if dialogue_resource == null:
		# A .dialogue only becomes loadable once Dialogue Manager has imported
		# it, so a fresh file is null until the editor has been focused once.
		push_warning("fishing_spot: dialogue/fishing_spot.dialogue has not been imported yet.")
		return
	DialogueManager.show_dialogue_balloon(dialogue_resource, title, [self, player])
	await DialogueManager.dialogue_ended
