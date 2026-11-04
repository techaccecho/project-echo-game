extends Node2D
## The Guardian crossing the plain: a gust that runs from one stone to the
## next and takes itself out of the tree when it has blown through.
##
## The trick is `local_coords = false` on the emitters — particles are left
## behind in world space as the node travels, so the gust draws its own wake
## instead of dragging a fixed puff along with it. Two emitters: fast thin
## streaks that read as the wind itself, and slower pale wisps behind them
## that read as what the wind is carrying.

## Set by travel(); how long the emitters keep running.
var _blowing := 0.0

@onready var _streaks: CPUParticles2D = $Streaks
@onready var _wisps: CPUParticles2D = $Wisps


## Run from `from` to `to` over `seconds`, then stop and clean up.
func travel(from: Vector2, to: Vector2, seconds: float) -> void:
	global_position = from
	var heading := (to - from).normalized()
	for p in [_streaks, _wisps]:
		p.direction = heading
		p.angle_min = rad_to_deg(heading.angle())
		p.angle_max = p.angle_min
		p.emitting = true
	_blowing = seconds
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "global_position", to, seconds)
	t.tween_callback(_settle)


func _settle() -> void:
	_streaks.emitting = false
	_wisps.emitting = false
	# Give what is already in the air time to fade before taking the node out.
	await get_tree().create_timer(maxf(_streaks.lifetime, _wisps.lifetime)).timeout
	queue_free()
