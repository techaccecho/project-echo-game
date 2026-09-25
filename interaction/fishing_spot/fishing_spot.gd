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

@export_group("What is on the bed")
## Something lying in this water that is not a fish. While it is still down
## there, casting drops into the pond-dive minigame instead of the river's
## letter drill, and this is what comes up. Leave null for ordinary water.
@export var prize: InvItem
## Set once the prize has been taken, so the dive plays only until it is won.
@export var prize_flag: String = ""
## Dialogue titles: spotting it, hooking it, and coming up empty.
@export var noticed_title: String = "glint"
@export var prize_title: String = "prize"
@export var prize_missed_title: String = "prize_missed"

@onready var interaction_area: InteractionArea = $InteractionArea
@onready var fish: AnimatedSprite2D = $Fish
@onready var glint: AnimatedSprite2D = $Glint

const POND_DIVE := preload("res://interaction/pond_dive/pond_dive.tscn")

var dialogue_resource = load("res://dialogue/fishing_spot.dialogue")
var player: CharacterBody2D
var busy: bool = false
## Fallback for a spot whose prize is not flagged, so it is not remembered.
var _noticed: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	interaction_area.interact = Callable(self, "_on_interact")
	# Every spot is the same scene, so without this they all turn in step and
	# the river reads as clockwork rather than fish.
	if fish != null:
		fish.frame = randi() % fish.sprite_frames.get_frame_count(fish.animation)
		fish.speed_scale = randf_range(0.85, 1.15)
	_refresh_glint()
	# The prompt has to change the moment the rod goes in the bag, not on the
	# next cast — the player may well walk here holding it before touching
	# anything else.
	if player != null and player.inv != null:
		player.inv.update.connect(_refresh_prompt)
		player.inv.selection_changed.connect(_refresh_prompt)
	_refresh_prompt()

## The prompt doubles as the hint: "fish" only shows once you have the rod, and
## something still on the bed asks to be looked at before it is fished for.
func _refresh_prompt() -> void:
	if not _player_has_rod():
		interaction_area.action_name = "look at the water"
	elif _has_prize():
		interaction_area.action_name = "fish for it" if _noticed_prize() else "look closer"
	else:
		interaction_area.action_name = "fish"
	_refresh_glint()


## Something catching the light on the water, while there is still something
## down there to catch it. Off once it has been fished up.
func _refresh_glint() -> void:
	if glint == null:
		return
	glint.visible = _has_prize()
	if glint.visible and not glint.has_meta("pulsing"):
		glint.set_meta("pulsing", true)
		var t := glint.create_tween().set_loops()
		t.tween_property(glint, "modulate:a", 0.25, 1.1).set_trans(Tween.TRANS_SINE)
		t.tween_property(glint, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


## Whether he has already spotted what is down there.
func _noticed_prize() -> bool:
	if prize_flag == "":
		return _noticed
	return Flags.has(prize_flag + ".seen")

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
	if _has_prize() and not _noticed_prize():
		# The first look is not a cast: he leans over the water and sees it.
		if prize_flag != "":
			Flags.set_flag(prize_flag + ".seen")
		else:
			_noticed = true
		await _say(noticed_title)
		busy = false
		_refresh_prompt()
		return
	if _has_prize():
		await _dive_for_prize(face_direction)
	else:
		await player.catch_fish(fish_pool, face_direction, min_wait_time, max_wait_time)
	busy = false
	_refresh_prompt()


## Something is still down there to be fished up.
func _has_prize() -> bool:
	return prize != null and (prize_flag == "" or not Flags.has(prize_flag))


## The same cast as always, but the view goes under: steer the bait down to
## the bed and come to rest beside the prize.
func _dive_for_prize(face_direction: Vector2) -> void:
	await player.cast_line(face_direction, min_wait_time, max_wait_time)
	var dive: PondDive = POND_DIVE.instantiate()
	get_tree().root.add_child(dive)
	var won: bool = await dive.play()
	dive.queue_free()
	# Deliberately no reel_in() here: its catch animation is him holding up a
	# fish, and this is a key. The dive has already shown it come off the bed
	# on the line, so he just straightens up and the line says the rest.
	if won:
		player.collect(prize)
		if prize_flag != "":
			Flags.set_flag(prize_flag)
	player.enable_movement()
	await _say(prize_title if won else prize_missed_title)

func _say(title: String) -> void:
	if dialogue_resource == null:
		# A .dialogue only becomes loadable once Dialogue Manager has imported
		# it, so a fresh file is null until the editor has been focused once.
		push_warning("fishing_spot: dialogue/fishing_spot.dialogue has not been imported yet.")
		return
	# He stands still to talk, the same as indoors. Walking off while the
	# balloon is up can drop him down a cliff, which changes the level out from
	# under this await — dialogue_ended never arrives, and whatever is waiting
	# on this call waits for the rest of the session. See house_interior's
	# _say() for the whole shape of it.
	var could_move: bool = player != null and player.movement_enabled
	if could_move:
		player.disable_movement()
	DialogueManager.show_dialogue_balloon(dialogue_resource, title, [self, player])
	await DialogueManager.dialogue_ended
	if could_move and is_instance_valid(player):
		player.enable_movement()
