extends Node
## The Haven has no sky, so it has no time of day: it sits at the same flat,
## slightly-too-bright pale whatever hour the player walked in. The opposite
## number to objects/storm.gd, and it works the same way — set the Clock's
## light override on entering the tree, clear it on leaving, so the real day
## comes straight back the moment the level is gone.

## What the whole level is lit by. Above 1.0 on purpose: the Haven is a touch
## blown out, which is what stops the pale ground reading as mere daylight.
@export var light: Color = Color(1.14, 1.10, 1.16)
## How long the change takes on arrival. A hard cut reads as a bug; this reads
## as eyes adjusting.
@export var fade_in: float = 1.1


func _enter_tree() -> void:
	Clock.set_light_override(light)


func _ready() -> void:
	if fade_in <= 0.0:
		return
	# Open on the day's own light and drift up to the Haven's, so the first
	# second of the level is the world changing rather than a new scene.
	# sky_tint() rather than tint(): _enter_tree has already set the override.
	var from := Clock.sky_tint()
	Clock.set_light_override(from)
	create_tween().tween_method(
		func(k: float) -> void: Clock.set_light_override(from.lerp(light, k)),
		0.0, 1.0, fade_in)


func _exit_tree() -> void:
	Clock.clear_light_override()
