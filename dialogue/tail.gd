extends Control

var tail_color: Color = Color("D9884C")
var _w: float = 0.0
var _h: float = 0.0

func draw_tail(w: float, h: float) -> void:
	_w = w
	_h = h
	size = Vector2(w, 40)
	position = Vector2(0, h)
	queue_redraw() # triggers _draw() next frame

func _draw() -> void:
	if _w == 0.0:
		return
	var tail_width: float = 20.0
	var tail_height: float = 18.0
	var points = PackedVector2Array([
		Vector2(_w / 2.0 - tail_width / 2.0, 0.0),
		Vector2(_w / 2.0 + tail_width / 2.0, 0.0),
		Vector2(_w / 2.0, tail_height)
	])
	draw_colored_polygon(points, tail_color)
