extends CanvasModulate
## Lights a level by the time of day. Drop one into any outdoor scene; set
## `base` if the level has a mood of its own (Level 2's gloom), and the two
## are multiplied. Interiors simply do not have one.

@export var base: Color = Color.WHITE


# The Clock counts DayLights so it knows whether the scene has a sky: the
# player's lamp stays off in a room, however late it is outside.
func _enter_tree() -> void:
	Clock.sky_count += 1


func _exit_tree() -> void:
	Clock.sky_count -= 1


func _process(_delta: float) -> void:
	color = base * Clock.tint()
