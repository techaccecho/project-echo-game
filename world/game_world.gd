extends Node2D
## Root of the legacy Level 1 world (game_world.tscn).
##
## This script only adds two things and never touches the GameLevel1 subtree:
##   • a Portal interaction that travels to the shell (Level 2),
##   • completion of any incoming transition (placing the player at the spawn
##     the SceneManager asked for, e.g. when returning from Level 2),
##   • camera limits, so the view never runs off the painted map,
##   • the blacksmith's front door, which opens onto its interior scene, and
##   • the opening arrival by boat, on a new game only.

const CLIFF_CUTSCENE := preload("res://cutscenes/hollow_to_cliff.tscn")
const ARRIVAL := preload("res://objects/arrival_sequence.tscn")
const CAMERA_BOUNDS := preload("res://objects/camera_bounds.tscn")
const HOUSE_DOOR := preload("res://objects/house_door.tscn")
## The blacksmith's front door: the step under the awning, just clear of the
## house's own collision so the player can stand on it.
const BLACKSMITH_DOOR := Vector2(-452, -822)
## The part of Level 1 the camera can show without running off the painted map,
## measured by walking every 640x360 window over the union of the level's tile
## layers and keeping the ones that are fully covered. Level 2 has had this
## since its cliff face was built; Level 1 never needed it while the player
## started in the middle, and does now that he starts on the shore.
const CAMERA_AREA := Rect2i(-1552, -1124, 1552, 1112)

@onready var portal: InteractionArea = $Portal

func _ready() -> void:
	if portal:
		portal.interact = Callable(self, "_on_portal")
	var bounds: Node = CAMERA_BOUNDS.instantiate()
	bounds.set("bounds", CAMERA_AREA)
	add_child(bounds)
	# Before on_standalone_ready(): the door carries the FrontDoor spawn marker,
	# and coming back out of the house needs it to exist when the player is
	# placed.
	var door: Node2D = HOUSE_DOOR.instantiate()
	door.position = BLACKSMITH_DOOR
	add_child(door)
	SceneManager.on_standalone_ready()
	# A new game opens with the player rowing in; coming back from Level 2 does
	# not. Instanced here rather than sitting in the scene so the level file is
	# untouched and the sequence only exists on the run that uses it.
	if SceneManager.take_arrival():
		var arrival: Node = ARRIVAL.instantiate()
		add_child(arrival)
		arrival.call("play")

func _on_portal() -> void:
	await SceneManager.play_cutscene(CLIFF_CUTSCENE)
	SceneManager.enter_shell("res://world/game_level_2.tscn", "Entrance")
