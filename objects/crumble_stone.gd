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


## Quicksand: the patch darkens and wets, and rings spread from where he
## went in, slowly, for as long as he is going under. It does not open a
## hole — the sand is still there afterwards, just not to be trusted.
func give_way() -> void:
	if _broken:
		return
	_broken = true
	var sag := create_tween()
	sag.set_parallel()
	sag.tween_property(slab, "modulate", Color(0.62, 0.52, 0.42), 0.4)
	sag.tween_property(slab, "position:y", slab.position.y + 1.0, 0.4)
	await get_tree().create_timer(0.3).timeout
	gave_way.emit()
	for i in 4:
		_ring(0.9 + i * 0.15)
		await get_tree().create_timer(0.7).timeout


## One ring of disturbed sand, growing and fading.
func _ring(seconds: float) -> void:
	var r := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 14:
		var a := TAU * k / 14.0
		pts.append(Vector2(cos(a), sin(a) * 0.55))
	r.polygon = pts
	r.color = Color(0.9, 0.82, 0.68, 0.7)
	r.scale = Vector2(2, 2)
	r.position = Vector2(0, 2)
	add_child(r)
	var t := create_tween()
	t.set_parallel()
	t.tween_property(r, "scale", Vector2(9, 9), seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(r, "color:a", 0.0, seconds)
	t.chain().tween_callback(r.queue_free)
