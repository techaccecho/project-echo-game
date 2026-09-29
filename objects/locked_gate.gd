extends Node2D
class_name LockedGate
## An iron gate set into the treeline, and the only way east out of the hollow.
##
## Shut, it is a wall: its body blocks the gap the trees leave, and whatever
## lies beyond cannot be reached. The right key winds the bars up out of the
## way and the gate stays open from then on, remembered by `open_flag`.
##
## The key is not consumed — it is the only one of its kind in the hollow and
## the player keeps it.
##
## Generic on purpose: point it at any InvItem and any flag. What waits on the
## far side is the level's business, not the gate's.
##
## The door is drawn a layer beneath the characters. Nobody can stand behind a
## gate set into a wall, and against its base the player's origin ties with
## the gate's in y-sort — which drew him behind the bars he was facing. Once it
## is open, whoever built the wall around it decides what hides him as he
## walks through (see east_gate.gd).

## Item that opens it. Leave null and it is never locked.
@export var required_item: InvItem
## Set once it is open, so it stays open.
@export var open_flag: String = "level1.gate_open"

@export_group("What it says")
@export_file("*.dialogue") var story: String = "res://dialogue/gate.dialogue"
## Rattling it with nothing to open it with.
@export var locked_title: String = "locked"
## The moment it gives.
@export var unlock_title: String = "unlock"
## Prompts, before and after the key is in hand.
@export var locked_action: String = "try the gate"
@export var unlock_action: String = "unlock the gate"

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var body: StaticBody2D = $Body
@onready var body_shape: CollisionShape2D = $Body/CollisionShape2D
@onready var interaction_area: InteractionArea = $InteractionArea

## Emitted when the bars finish winding up. The level listens to let whatever
## is beyond the gate come into effect.
signal opened

var player: CharacterBody2D
var _busy := false


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	interaction_area.interact = Callable(self, "_on_interact")
	if open_flag != "" and Flags.has(open_flag):
		_stand_open()
		return
	sprite.play("shut")
	# The prompt has to change the moment the key goes in the bag, not on the
	# next rattle of the bars.
	if player != null and player.inv != null:
		player.inv.update.connect(_refresh_prompt)
	_refresh_prompt()


func is_open() -> bool:
	return open_flag != "" and Flags.has(open_flag)


func _refresh_prompt() -> void:
	# The inventory outlives the gate's prompt: once the bars are up the area
	# is gone, and a later pickup must not come looking for it.
	if interaction_area == null or not is_instance_valid(interaction_area):
		return
	interaction_area.action_name = unlock_action if _player_has_key() else locked_action


func _player_has_key() -> bool:
	if required_item == null:
		return true
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	return player != null and player.inv != null and player.inv.has(required_item)


func _on_interact() -> void:
	if _busy or is_open():
		return
	if not _player_has_key():
		await _say(locked_title)
		return
	_busy = true
	await _say(unlock_title)
	await _open()
	_busy = false


## The bars wind up out of the way, and the road is open.
func _open() -> void:
	if open_flag != "":
		Flags.set_flag(open_flag)
	sprite.play("open")
	await sprite.animation_finished
	_stand_open()
	opened.emit()


## Open, and staying that way: no bars, no body, nothing left to press.
func _stand_open() -> void:
	sprite.play("open")
	sprite.frame = sprite.sprite_frames.get_frame_count("open") - 1
	sprite.pause()
	body_shape.set_deferred("disabled", true)
	if player != null and is_instance_valid(player) and player.inv != null 			and player.inv.update.is_connected(_refresh_prompt):
		player.inv.update.disconnect(_refresh_prompt)
	if interaction_area != null and is_instance_valid(interaction_area):
		InteractionManager.deregister_area(interaction_area)
		interaction_area.queue_free()


func _say(title: String) -> void:
	if story == "":
		return
	var res = load(story)
	if res == null:
		# A .dialogue only becomes loadable once Dialogue Manager has imported
		# it, so a fresh file is null until the editor has been focused once.
		push_warning("locked_gate: %s has not been imported yet." % story)
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	DialogueManager.show_dialogue_balloon(res, title, [self, player])
	await DialogueManager.dialogue_ended
