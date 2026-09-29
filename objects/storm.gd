extends Node
## A storm with no daybreak: the level it sits in is night for as long as
## the player is there, lit only by lightning. Sets the Clock's light
## override on entering the tree and clears it on leaving, so the sky comes
## back the moment the level is gone. The flashes are the override itself
## jumping to white for a frame or two — every DayLight and NightLight
## reads the same tint, so the whole world jumps with it.

## How dark it stays between flashes.
@export var dark: Color = Color(0.16, 0.15, 0.26)
## The colour of a flash at its brightest.
@export var flash: Color = Color(1.35, 1.35, 1.5)
## Seconds between strikes: picked at random in this range.
@export var interval: Vector2 = Vector2(6.0, 16.0)
## Thunder follows the flash after this long — near strikes are loud and
## quick, far ones late and low.
@export var thunder_delay: Vector2 = Vector2(0.3, 1.8)
@export var thunder_volume_db: float = -6.0

const THUNDER := "res://audio/sfx/thunder.wav"

var _until_strike := 0.0
var _striking := false


func _enter_tree() -> void:
	Clock.set_light_override(dark)
	_until_strike = randf_range(2.0, interval.y * 0.5)


func _exit_tree() -> void:
	Clock.clear_light_override()


func _process(delta: float) -> void:
	if _striking:
		return
	_until_strike -= delta
	if _until_strike <= 0.0:
		_strike()


## Two or three flickers, then the light dies back over a quarter second.
func _strike() -> void:
	_striking = true
	var delay := randf_range(thunder_delay.x, thunder_delay.y)
	var near := 1.0 - (delay - thunder_delay.x) / (thunder_delay.y - thunder_delay.x)
	var t := create_tween()
	var peak := dark.lerp(flash, 0.6 + 0.4 * near)
	t.tween_callback(Clock.set_light_override.bind(peak))
	t.tween_interval(0.05)
	t.tween_callback(Clock.set_light_override.bind(dark.lerp(peak, 0.3)))
	t.tween_interval(0.07)
	t.tween_callback(Clock.set_light_override.bind(peak))
	t.tween_interval(0.04)
	t.tween_method(func(k: float) -> void: Clock.set_light_override(peak.lerp(dark, k)), 0.0, 1.0, 0.3)
	t.tween_interval(delay)
	t.tween_callback(func() -> void:
		Audio.sfx(THUNDER, thunder_volume_db - 8.0 * (1.0 - near), 0.12))
	t.tween_callback(func() -> void:
		_striking = false
		_until_strike = randf_range(interval.x, interval.y))
