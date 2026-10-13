extends Node2D
## Root of the legacy Level 1 world (game_world.tscn).
##
## This script only adds two things and never touches the GameLevel1 subtree:
##   • the east gate and, in its gateway, the Portal that travels to the shell
##     (Level 2) — the portal is dead until the gate is unlocked,
##   • completion of any incoming transition (placing the player at the spawn
##     the SceneManager asked for, e.g. when returning from Level 2),
##   • the time-of-day light and camera limits,
##   • Jory, who greets you on the meadow above the landing,
##   • the blacksmith's front door and the fishing hut, each with an interior,
##   • fish and morning gulls on the western sea,
##   • the lanterns that mark the lived-in places after dark, and
##   • the opening arrival by boat, on a new game only.

const CLIFF_CUTSCENE := preload("res://cutscenes/hollow_to_cliff.tscn")
const ARRIVAL := preload("res://objects/arrival_sequence.tscn")
const CAMERA_BOUNDS := preload("res://objects/camera_bounds.tscn")
const HOUSE_DOOR := preload("res://objects/house_door.tscn")
const DAY_LIGHT := preload("res://objects/day_light.tscn")
const FISHING_HUT := preload("res://objects/fishing_hut.tscn")
const GREETER := preload("res://character/npc_greeter.tscn")
## Jory sits by a patch of tall grass on the meadow, up from the landing on
## the way inland.
const GREETER_AT := Vector2(-988, -222)
const SEA_LIFE := preload("res://objects/sea_life.tscn")
const LANTERN := preload("res://objects/lantern.tscn")
const NIGHT_LIGHT := preload("res://objects/night_light.tscn")
## Where the lamps hang once the sun is down: either side of the smith's
## door, the workshop's front posts, beside the hut's door, and along the
## bridge rails so the crossing is the one lit line through the dark.
const LANTERNS := [
	Vector2(-480, -818), Vector2(-424, -818),        # blacksmith's door
	Vector2(-270, -822), Vector2(-138, -822),        # workshop front
	Vector2(-1150, -842),                            # fishing hut door
	Vector2(-842, -458), Vector2(-760, -458), Vector2(-678, -458),   # bridge, north rail
	Vector2(-801, -412), Vector2(-719, -412),                        # bridge, south rail
]
## The forge in the workshop never quite goes out.
const FORGE_GLOW := Vector2(-214, -840)
const MORNING_GULLS := preload("res://objects/morning_gulls.tscn")
## The hut's y-sort anchor: 20px north of its actual bottom-left (see
## FishingHut), on the meadow in the map's north-west corner, between the
## cliff edge and the pines.
const HUT_AT := Vector2(-1232, -872)
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
## The way east. The portal sits in its gateway and does nothing until the
## bars are up — the gate's own body is what keeps him out of it meanwhile,
## and this stops him reaching through the bars to travel.
@onready var gate: LockedGate = $GameLevel1/EastGate/Gate

func _ready() -> void:
	if portal:
		portal.interact = Callable(self, "_on_portal")
	if gate:
		gate.opened.connect(_on_gate_opened)
		_arm_portal(gate.is_open())
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
	var greeter: Node2D = GREETER.instantiate()
	greeter.position = GREETER_AT
	$GameLevel1.add_child(greeter)
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
	for at in LANTERNS:
		var lantern: Node2D = LANTERN.instantiate()
		lantern.position = at
		$GameLevel1.add_child(lantern)
	var forge: Node2D = NIGHT_LIGHT.instantiate()
	forge.position = FORGE_GLOW
	forge.set("radius", 70.0)
	forge.set("strength", 0.8)
	forge.set("warm", Color(1.0, 0.55, 0.25))
	forge.set("flicker", 0.3)
	add_child(forge)
	SceneManager.on_standalone_ready()
	# A new game opens with the player rowing in; coming back from Level 2 does
	# not. Instanced here rather than sitting in the scene so the level file is
	# untouched and the sequence only exists on the run that uses it.
	if SceneManager.take_arrival():
		var arrival: Node = ARRIVAL.instantiate()
		add_child(arrival)
		arrival.call("play")

## The bars are up: the road east is real now.
func _on_gate_opened() -> void:
	_arm_portal(true)


func _arm_portal(on: bool) -> void:
	if portal == null:
		return
	portal.monitoring = on
	if not on:
		InteractionManager.deregister_area(portal)


func _on_portal() -> void:
	# The story card plays the first time up the path; after that it is just
	# the walk.
	await SceneManager.play_cutscene(CLIFF_CUTSCENE, "cutscene.hollow_to_cliff")
	SceneManager.enter_shell("res://world/game_level_2.tscn", "Entrance")
