extends Node2D
class_name HouseInterior
## A room you can go into: the blacksmith's house, the fishing hut, whatever
## comes next. Entered through a HouseDoor in a level and left by walking
## back out over the doormat.
##
## Standalone scene, like Level 1: it brings its own player and a camera that
## holds on the room rather than following. SceneManager.exit_to() carries the
## player between here and the level, and the shared inventory resource means
## whatever he is carrying comes with him.
##
## The furniture answers to E through InteractionAreas under `Interact`,
## wired up here by name: a name in `seats` is a chair, `bed` is the bed, and
## anything in `lines` just says its line — once; see _say() for repeats.
## Sleeping moves the Clock on to the next morning.

## Level scene and spawn marker to return to.
@export_file("*.tscn") var outside: String = "res://world/game_world.tscn"
@export var outside_spawn: String = "FrontDoor"
## The .dialogue with this room's lines. Loaded at runtime, not preloaded: a
## fresh .dialogue is unloadable until Dialogue Manager has imported it.
@export_file("*.dialogue") var story: String = ""

## Chair area name -> {"at": Vector2 seat position, "face": Vector2 direction}.
@export var seats: Dictionary = {}
## Area name of the bed, and where he sits on it / stands up from it.
@export var bed: String = "Bed"
@export var bed_sit: Vector2 = Vector2.ZERO
@export var bed_rise: Vector2 = Vector2.ZERO
## Area name -> dialogue title, for the things that are just worth a look.
@export var lines: Dictionary = {}
## Dialogue titles for the bed's two lines.
@export var bed_line: String = "bed"
@export var woke_line: String = "woke"
@export var chair_line: String = "chair"

var _leaving := false
var _busy := false
var _seated := ""
var _player: CharacterBody2D


func _ready() -> void:
	SceneManager.on_standalone_ready()
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		# He has just come in through the door behind him.
		_player.last_direction = Vector2.UP
		_player.update_animation(Vector2.ZERO, false)
	var interact := get_node_or_null("Interact")
	if interact:
		for area in interact.get_children():
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
	SceneManager.exit_to(outside, outside_spawn)


# --- the furniture ----------------------------------------------------------

func _on_interact(what: String) -> void:
	if _busy or _player == null:
		return
	if what == bed:
		await _sleep()
	elif seats.has(what):
		if _seated == what:
			_stand()
		else:
			await _sit(what)
	elif lines.has(what):
		await _say(str(lines[what]))


func _sit(chair: String) -> void:
	_busy = true
	if _seated != "":
		_stand()
	var seat: Dictionary = seats[chair]
	_player.movement_enabled = false
	# Over the chair, not tucked behind it: the seat is what he sits on.
	_player.z_index = 1
	await _slide(seat["at"], 0.25)
	_player.last_direction = seat["face"]
	# The kneeling frame reads as sitting; it only faces right, so flip for a
	# chair on the far side of the table. A chair facing the camera uses the
	# front-on kneel.
	if seat["face"] == Vector2.DOWN:
		_player.hold_pose(_player.POSE_SIT_DOWN)
	else:
		_player.hold_pose(_player.POSE_SIT_SIDE, seat["face"] == Vector2.LEFT)
	_seated = chair
	await _say(chair_line)
	_busy = false


func _stand() -> void:
	if _seated == "":
		return
	var seat: Dictionary = seats[_seated]
	_seated = ""
	_player.release_pose()
	_player.z_index = 0
	_player.last_direction = seat["face"]
	_player.update_animation(Vector2.ZERO, false)
	# A step back from the chair, so he is not standing in it.
	_player.global_position = seat["at"] + Vector2(0, 18)
	_player.movement_enabled = true


## Sit on the edge of the bed, lights out, and it is morning. The sheet's
## only lying-down frames are a 13px heap that reads as nothing, while its
## kneeling frame is a convincing sit, so that is the pose.
func _sleep() -> void:
	_busy = true
	if _seated != "":
		_stand()
	_player.movement_enabled = false
	await _say(bed_line)
	# On top of the blanket rather than under the bed: y-sort would put the
	# bed over him, so he is lifted a layer for as long as he is on it.
	_player.z_index = 1
	await _slide(bed_sit, 0.35)
	_player.last_direction = Vector2.DOWN
	_player.hold_pose(_player.POSE_SIT_DOWN)
	await get_tree().create_timer(1.1).timeout
	await SceneManager.fade(1.0)
	await get_tree().create_timer(1.6).timeout
	Clock.sleep_until_morning()
	_player.release_pose()
	_player.z_index = 0
	_player.global_position = bed_rise
	_player.last_direction = Vector2.DOWN
	_player.update_animation(Vector2.ZERO, false)
	await SceneManager.fade(0.0)
	await _say(woke_line)
	_player.movement_enabled = true
	_busy = false


# --- helpers ----------------------------------------------------------------

func _slide(to: Vector2, seconds: float) -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_player, "global_position", to, seconds)
	await t.finished


## A line plays in full the first time and is remembered as a flag; after
## that the room says its `<title>_again` line if the dialogue has one, and
## otherwise nothing. Nobody needs to be told twice that the bed is dusty.
func _say(title: String) -> void:
	if story == "":
		return
	var res = load(story)
	if res == null:
		push_warning("HouseInterior: %s has not been imported yet." % story)
		return
	var flag := "%s.%s" % [story.get_file().get_basename(), title]
	var use := title
	if Flags.has(flag):
		use = title + "_again"
		if not res.titles.has(use):
			return
	else:
		Flags.set_flag(flag)
	DialogueManager.show_dialogue_balloon(res, use, [_player])
	await DialogueManager.dialogue_ended
