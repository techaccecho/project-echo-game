extends Node2D
## One patch of the sand crossing.
##
## Firm sand and quicksand look identical on purpose — working out which is
## which is the whole puzzle. The bridge owns the pattern; this just knows how
## to lie on the path and how to give way, leaving a hole into the cliff.

signal gave_way

## Whether this one holds. Set by CrumbleBridge from its pattern.
var safe: bool = true

## The patch: the path's own dirt tile, lightened, with a faint drift of
## sand ripples over it — so it reads as a sandy stretch of the same path
## rather than a beach dropped onto a cliff.
@onready var slab: Node2D = $Sand
@onready var ripple: Sprite2D = $Sand/Ripple
@onready var hole: Sprite2D = $Hole

var _broken: bool = false


func _ready() -> void:
	hole.visible = false


func is_broken() -> bool:
	return _broken


## The sand darkens and sags for a moment, then pours away into the drop.
func give_way() -> void:
	if _broken:
		return
	_broken = true
	Audio.sfx("res://audio/sfx/stone_crumble.wav", -8.0, 0.25)

	var sag := create_tween()
	sag.set_parallel()
	sag.tween_property(slab, "modulate", Color(0.6, 0.5, 0.4), 0.22)
	sag.tween_property(slab, "position:y", slab.position.y + 2.0, 0.22)
	await sag.finished

	hole.visible = true
	hole.modulate.a = 0.0
	var open := create_tween()
	open.set_parallel()
	open.tween_property(hole, "modulate:a", 1.0, 0.25)
	open.tween_property(slab, "scale", Vector2(0.15, 0.15), 0.38) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	open.tween_property(slab, "modulate:a", 0.0, 0.38)

	gave_way.emit()
	await open.finished
	slab.visible = false
