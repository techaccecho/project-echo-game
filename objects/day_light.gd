extends CanvasModulate
## Lights a level by the time of day. Drop one into any outdoor scene; set
## `base` if the level has a mood of its own (Level 2's gloom), and the two
## are multiplied. Interiors simply do not have one.

@export var base: Color = Color.WHITE

func _process(_delta: float) -> void:
	color = base * Clock.tint()
