extends Node2D
## Root of the legacy Level 1 world (game_world.tscn).
##
## This script only adds two things and never touches the GameLevel1 subtree:
##   • a Portal interaction that travels to the shell (Level 2),
##   • completion of any incoming transition (placing the player at the spawn
##     the SceneManager asked for, e.g. when returning from Level 2),
##   • the time-of-day light and camera limits,
##   • the blacksmith's front door and the fishing hut, each with an interior,
##   • fish and morning gulls on the western sea, and
##   • the opening arrival by boat, on a new game only.

const CLIFF_CUTSCENE := preload("res://cutscenes/hollow_to_cliff.tscn")
const ARRIVAL := preload("res://objects/arrival_sequence.tscn")
const CAMERA_BOUNDS := preload("res://objects/camera_bounds.tscn")
const HOUSE_DOOR := preload("res://objects/house_door.tscn")
const DAY_LIGHT := preload("res://objects/day_light.tscn")
const FISHING_HUT := preload("res://objects/fishing_hut.tscn")
const SEA_LIFE := preload("res://objects/sea_life.tscn")
const MORNING_GULLS := preload("res://objects/morning_gulls.tscn")
## Bottom-left of the hut, on the meadow in the map's north-west corner,
## between the cliff edge and the pines.
const HUT_AT := Vector2(-1232, -852)
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
	add_child(DAY_LIGHT.instantiate())
	var bounds: Node = CAMERA_BOUNDS.instantiate()
	bounds.set("bounds", CAMERA_AREA)
	add_child(bounds)
	# Before on_standalone_ready(): the door carries the FrontDoor spawn marker,
	# and coming back out of the house needs it to exist when the player is
	# placed.
	var door: Node2D = HOUSE_DOOR.instantiate()
	door.position = BLACKSMITH_DOOR
	add_child(door)
	# Inside GameLevel1 so it y-sorts against the player like the houses do.
	var hut: Node2D = FISHING_HUT.instantiate()
	hut.position = HUT_AT
	hut.z_index = 5
	$GameLevel1.add_child(hut)
	# The sea: fish leaping across the western water, and gulls off the hut's
	# shore in the mornings. Above the sea layers, below the player.
	var sea: Node2D = SEA_LIFE.instantiate()
	sea.z_index = 2
	add_child(sea)
	var gulls: Node2D = MORNING_GULLS.instantiate()
	# Open water off the hut, checked against the sea and islet layers.
	gulls.floating = PackedVector2Array([Vector2(-1374, -836), Vector2(-1422, -812),
			Vector2(-1342, -822), Vector2(-1454, -860)])
	gulls.flying = PackedVector2Array([Vector2(-1390, -884)])
	gulls.z_index = 2
	add_child(gulls)
	SceneManager.on_standalone_ready()
	# A new game opens with the player rowing in; coming back from Level 2 does
	# not. Instanced here rather than sitting in the scene so the level file is
	# untouched and the sequence only exists on the run that uses it.
	if SceneManager.take_arrival():
		var arrival: Node = ARRIVAL.instantiate()
		add_child(arrival)
		arrival.call("play")

func _on_portal() -> void:
	# The story card plays the first time up the path; after that it is just
	# the walk.
	await SceneManager.play_cutscene(CLIFF_CUTSCENE, "cutscene.hollow_to_cliff")
	SceneManager.enter_shell("res://world/game_level_2.tscn", "Entrance")
