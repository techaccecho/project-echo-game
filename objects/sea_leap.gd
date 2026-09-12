extends AnimatedSprite2D
## One leap out of the water: a fish (six colours) or, rarely, a dolphin.
## Invisible between leaps; SeaLife owns a handful and points them at water.

const FISH_KINDS := 6

func _ready() -> void:
	visible = false
	animation_finished.connect(_on_done)

func leap(at: Vector2, dolphin: bool = false) -> void:
	global_position = at
	flip_h = randf() < 0.5
	visible = true
	if dolphin:
		play("dolphin")
	else:
		play("jump_%d" % (randi() % FISH_KINDS))

func _on_done() -> void:
	visible = false
