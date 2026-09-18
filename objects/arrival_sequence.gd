extends Node2D
class_name ArrivalSequence
## The opening: the player rows in out of the west, beaches the boat on the
## gravel spit and steps ashore. Control is handed over the moment he is on
## grass.
##
## Instanced in code by game_world.gd when SceneManager says this is a new
## game, so returning to Level 1 from Level 2 never replays it. The boat is
## deliberately left where it grounds — it is the only evidence in the level
## that the player came from somewhere.
##
## The camera needs no special handling: it rides the player as usual, and
## Level 1's CameraBounds stop it at the west edge of the map, so the boat
## enters frame from the left and crosses it instead of sitting dead centre.

const BOAT := preload("res://objects/wood_canoe.tscn")

@export_group("Path")
## Out in open water, at the left edge of the held camera frame.
@export var boat_from := Vector2(-1500, -176)
## Where the hull grounds, against the west edge of the gravel spit.
@export var boat_to := Vector2(-1334, -158)
## First step onto the gravel.
@export var step_out := Vector2(-1300, -146)
## Where the player is standing when the game starts. On grass, clear of the
## shoreline, facing inland.
@export var walk_to := Vector2(-1208, -152)
## The canoe art points north with its wake at the stern, so a boat running
## east is turned a quarter turn clockwise — bow to the right, wake trailing.
@export var boat_heading := 90.0

## A stop on the gravel before the turn up onto the grass, so the walk ashore
## bends the way a person's would instead of running dead straight.
@export var sand_stop := Vector2(-1262, -142)

@export_group("Pacing")
@export var row_time := 4.5
## Sitting in the grounded boat before getting up.
@export var ground_pause := 0.7
@export var hop_time := 0.42
## Standing on the gravel taking the place in, before walking on.
@export var look_pause := 0.5

## Where the player sits in the hull, relative to it.
const RIDE := Vector2(0, -4)
## How high the hop out of the boat arcs, in pixels.
const HOP_RISE := 11.0
const SPLASH := preload("res://objects/water_splash.tscn")
const SPLASH_SFX := "res://audio/sfx/splash.wav"
## What he thinks, standing on the grass, before the game is his. Loaded at
## runtime rather than preloaded: a .dialogue is only loadable once Dialogue
## Manager has imported it, and a preload of a fresh file fails to parse.
const STORY := "res://dialogue/arrival.dialogue"
const STORY_TITLE := "ashore"

var _player: Node2D
var _boat: Node2D
var _riding := false


func _ready() -> void:
	add_to_group("arrival")


func _process(_delta: float) -> void:
	if _riding and _player != null and _boat != null:
		_player.global_position = _boat.global_position + RIDE


## Await this. Returns once the player is ashore and moving under his own steam.
func play() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return
	_player.set("movement_enabled", false)

	# A carrier for the boat, so the hull can keep bobbing and yawing in its
	# own local space while the carrier is tweened along the course.
	_boat = Node2D.new()
	_boat.z_index = 4          # the player is 5, and rides above the hull
	_boat.global_position = boat_from
	add_child(_boat)
	var hull: Node2D = BOAT.instantiate()
	hull.rotation_degrees = boat_heading
	_boat.add_child(hull)

	# Sitting, facing the shore. Idle, not walking — he is being carried.
	_player.global_position = boat_from + RIDE
	_face(Vector2.RIGHT)
	_riding = true

	var row := create_tween()
	row.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	row.tween_property(_boat, "global_position", boat_to, row_time)
	await row.finished
	await _ground()
	await get_tree().create_timer(ground_pause).timeout

	await _hop_out()
	await get_tree().create_timer(0.3).timeout

	# On the gravel: a look up the shore, then along it, before setting off.
	_face(Vector2.UP)
	await get_tree().create_timer(look_pause).timeout
	_face(Vector2.RIGHT)
	await get_tree().create_timer(0.3).timeout

	await _player.call("walk_to_point", sand_stop)
	await _player.call("walk_to_point", walk_to)
	_face(Vector2.RIGHT)
	await _narrate()
	_player.set("movement_enabled", true)


# --- beats ------------------------------------------------------------------

## The hull runs onto the gravel: a wash under the bow, a rock through the
## boat, and the rider lurches with it.
func _ground() -> void:
	_splash(_boat.global_position + Vector2(18, 6), -14.0)
	var rock := create_tween()
	rock.tween_property(_boat, "rotation_degrees", 3.5, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rock.tween_property(_boat, "rotation_degrees", -1.5, 0.22) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rock.tween_property(_boat, "rotation_degrees", 0.0, 0.26) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var sprite := _sprite()
	if sprite:
		var lurch := create_tween()
		lurch.tween_property(sprite, "offset:x", 2.0, 0.1)
		lurch.tween_property(sprite, "offset:x", 0.0, 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await rock.finished


## Up and over the side: a real arc, a stretch on the way up and a squash on
## landing, a splash in the shallows, and the boat kicks back off the push.
func _hop_out() -> void:
	_riding = false
	var sprite := _sprite()
	var from := _player.global_position
	_player.call("update_animation", Vector2.RIGHT, false)   # legs going

	# The arc is x and y on separate tweens: x runs straight through, y rises
	# fast and falls faster. (One parallel tween cannot do it — chain() there
	# waits for every earlier tweener, x included.)
	var hop := create_tween()
	hop.tween_property(_player, "global_position:x", step_out.x, hop_time)
	var up := hop_time * 0.45
	var arc := create_tween()
	arc.tween_property(_player, "global_position:y", from.y - HOP_RISE, up) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arc.tween_property(_player, "global_position:y", step_out.y, hop_time - up) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if sprite:
		var stretch := create_tween()
		stretch.tween_property(sprite, "scale", Vector2(0.86, 1.16), up) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# The boat takes the push-off: a kick west and a rock.
	var kick := create_tween()
	kick.tween_property(_boat, "global_position:x", boat_to.x - 3.0, 0.16) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	kick.parallel().tween_property(_boat, "rotation_degrees", -4.0, 0.16) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	kick.tween_property(_boat, "rotation_degrees", 2.0, 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	kick.tween_property(_boat, "rotation_degrees", 0.0, 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await hop.finished

	# Landing in the wet gravel at the water's edge.
	_splash(_player.global_position + Vector2(0, 6), -10.0)
	if sprite:
		var land := create_tween()
		land.tween_property(sprite, "scale", Vector2(1.18, 0.82), 0.07)
		land.tween_property(sprite, "scale", Vector2.ONE, 0.22) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_face(Vector2.RIGHT)


## A few lines of narration in the dialogue balloon, and the game waits on
## them. Movement stays locked until the sequence lifts it afterwards, so the
## dialogue itself carries no enable/disable mutations.
func _narrate() -> void:
	var story = load(STORY)
	if story == null:
		push_warning("ArrivalSequence: %s has not been imported yet." % STORY)
		return
	DialogueManager.show_dialogue_balloon(story, STORY_TITLE, [_player])
	await DialogueManager.dialogue_ended


# --- helpers ----------------------------------------------------------------

## Stand still facing `dir`. The player's own idle picks the pose from
## last_direction, so setting that and asking for "no input" is the idle.
func _face(dir: Vector2) -> void:
	_player.set("last_direction", dir)
	_player.call("update_animation", Vector2.ZERO, false)


func _sprite() -> AnimatedSprite2D:
	return _player.get_node_or_null("Movement") as AnimatedSprite2D


func _splash(at: Vector2, volume_db: float) -> void:
	var fx: Node2D = SPLASH.instantiate()
	fx.global_position = at
	fx.z_index = 3
	add_child(fx)
	Audio.sfx(SPLASH_SFX, volume_db, 0.08)
