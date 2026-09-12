extends Node2D
## Inside the blacksmith's house. A single room, entered through the front
## door in Level 1 and left by walking back out over the doormat.
##
## Standalone scene, like Level 1: it brings its own player and a camera that
## holds on the room rather than following. SceneManager.exit_to() carries the
## player between here and the level, and the shared inventory resource means
## whatever he is carrying comes with him.
##
## The furniture answers to E: the bed puts you to sleep, the chairs seat you,
## and the rest is worth a look. The prompts are InteractionAreas under
## `Interact`, wired up here by name.

const OUTSIDE := "res://world/game_world.tscn"
## Marker in Level 1 the player is put on when he steps out — the front step.
const OUTSIDE_SPAWN := "FrontDoor"
const STORY := "res://dialogue/blacksmith_house.dialogue"

## Where he ends up for each piece of furniture, and which way he faces.
const SEATS := {
	"ChairL": {"at": Vector2(108, 132), "face": Vector2.RIGHT},
	"ChairR": {"at": Vector2(148, 132), "face": Vector2.LEFT},
}
## He sits on the edge of the bed before the lights go out: the sheet's only
## lying-down frames are a 13px heap of hair that reads as nothing at all,
## while its kneeling frame is a convincing sit.
const BED_SIT := Vector2(208, 85)
const BED_RISE := Vector2(190, 118)    ## standing beside it afterwards

var _leaving := false
var _busy := false
var _seated := ""              ## name of the chair he is in, or ""
var _player: CharacterBody2D


func _ready() -> void:
	SceneManager.on_standalone_ready()
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		# He has just come in through the door behind him.
		_player.last_direction = Vector2.UP
		_player.update_animation(Vector2.ZERO, false)
	for area in $Interact.get_children():
		area.interact = Callable(self, "_on_interact").bind(area.name)


func _process(_delta: float) -> void:
	# Any step stands him up. Movement is locked while seated, so the input
	# has to be read here rather than left to the player.
	if _seated != "" and not _busy and (Input.is_action_just_pressed("up")
			or Input.is_action_just_pressed("down")
			or Input.is_action_just_pressed("left")
			or Input.is_action_just_pressed("right")):
		_stand()


func _on_exit_body_entered(body: Node2D) -> void:
	if _leaving or not body.is_in_group("player"):
		return
	_leaving = true
	SceneManager.exit_to(OUTSIDE, OUTSIDE_SPAWN)


# --- the furniture ----------------------------------------------------------

func _on_interact(what: String) -> void:
	if _busy or _player == null:
		return
	match what:
		"Bed":
			await _sleep()
		"ChairL", "ChairR":
			if _seated == what:
				_stand()
			else:
				await _sit(what)
		"Hearth":
			await _say("hearth")
		"Desk":
			await _say("desk")
		"Swords":
			await _say("swords")
		"Barrel":
			await _say("barrel")
		"Crates":
			await _say("crates")


func _sit(chair: String) -> void:
	_busy = true
	if _seated != "":
		_stand()
	var seat: Dictionary = SEATS[chair]
	_player.movement_enabled = false
	# Over the chair, not tucked behind it: the seat is what he sits on.
	_player.z_index = 1
	await _slide(seat["at"], 0.25)
	_player.last_direction = seat["face"]
	# The kneeling frame reads as sitting; it only faces right, so flip for a
	# chair on the far side of the table.
	_player.hold_pose(_player.POSE_SIT_SIDE, seat["face"] == Vector2.LEFT)
	_seated = chair
	await _say("chair")
	_busy = false


func _stand() -> void:
	if _seated == "":
		return
	var seat: Dictionary = SEATS[_seated]
	_seated = ""
	_player.release_pose()
	_player.z_index = 0
	_player.last_direction = seat["face"]
	_player.update_animation(Vector2.ZERO, false)
	# A step back from the chair, so he is not standing in it.
	_player.global_position = seat["at"] + Vector2(0, 18)
	_player.movement_enabled = true


func _sleep() -> void:
	_busy = true
	if _seated != "":
		_stand()
	_player.movement_enabled = false
	await _say("bed")
	# On top of the blanket rather than under the bed: y-sort would put the
	# bed over him, so he is lifted a layer for as long as he is on it.
	_player.z_index = 1
	await _slide(BED_SIT, 0.35)
	_player.last_direction = Vector2.DOWN
	_player.hold_pose(_player.POSE_SIT_DOWN)
	await get_tree().create_timer(1.1).timeout
	await SceneManager.fade(1.0)
	await get_tree().create_timer(1.6).timeout
	_player.release_pose()
	_player.z_index = 0
	_player.global_position = BED_RISE
	_player.last_direction = Vector2.DOWN
	_player.update_animation(Vector2.ZERO, false)
	await SceneManager.fade(0.0)
	await _say("woke")
	_player.movement_enabled = true
	_busy = false


# --- helpers ----------------------------------------------------------------

func _slide(to: Vector2, seconds: float) -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_player, "global_position", to, seconds)
	await t.finished


func _say(title: String) -> void:
	var story = load(STORY)
	if story == null:
		push_warning("BlacksmithInterior: %s has not been imported yet." % STORY)
		return
	DialogueManager.show_dialogue_balloon(story, title, [_player])
	await DialogueManager.dialogue_ended
