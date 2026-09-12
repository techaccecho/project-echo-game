extends Node2D
class_name HouseDoor
## The front door of a building you can go into.
##
## Stand on the step and press E to enter; the interior scene puts you back on
## the same step when you leave, via the spawn marker this node carries. Drop
## it on any doorstep and point it at an interior.

## The interior scene this door opens onto.
@export_file("*.tscn") var interior: String = "res://world/blacksmith_interior.tscn"
## Spawn marker inside the interior to arrive on.
@export var interior_spawn: String = "Entrance"

@onready var area: InteractionArea = $InteractionArea


func _ready() -> void:
	area.interact = Callable(self, "_enter")


func _enter() -> void:
	SceneManager.exit_to(interior, interior_spawn)
