extends Node2D
class_name SeaLife
## Fish leaping out of the sea, now and then, wherever there is open water.
##
## Rather than hand-placing splashes, it samples random points in `area` and
## keeps the ones that are on a water layer and on no land layer — the sea in
## Level 1 is full of islets, and a fish jumping out of a cliff would be a
## strange sight. Layers are found by name so a level's own tilemaps can be
## used as they are.

const LEAP := preload("res://objects/sea_leap.tscn")

## World rectangle to sample, in pixels.
@export var area := Rect2(-1540, -1000, 240, 1000)
## TileMapLayer names that count as water / as land.
@export var water_layers: Array[String] = ["SeaLight", "SeaMedium"]
@export var land_layers: Array[String] = ["Islands", "IslandProps1", "IslandProps2",
	"TileMapLayer", "GrassSand", "GrassCliffWater", "EdgeCliffSea", "SandUnderRiverWater"]
## Seconds between leaps, at the low and high end.
@export var interval_min := 1.4
@export var interval_max := 4.0
## One leap in this many is a dolphin.
@export var dolphin_one_in := 14
## How many can be in the air at once.
@export var pool := 4
## Candidate points to keep after sampling.
@export var samples := 160

var _spots: PackedVector2Array = PackedVector2Array()
var _leaps: Array[AnimatedSprite2D] = []
var _timer := 0.0


func _ready() -> void:
	for i in pool:
		var l: AnimatedSprite2D = LEAP.instantiate()
		add_child(l)
		_leaps.append(l)
	# Layers may be several scenes deep; resolve after everything is in.
	call_deferred("_find_spots")
	_timer = randf_range(0.5, 1.5)


func _find_spots() -> void:
	var water: Array[TileMapLayer] = []
	var land: Array[TileMapLayer] = []
	for n in _all(get_tree().current_scene):
		if n is TileMapLayer:
			if n.name in water_layers:
				water.append(n)
			elif n.name in land_layers:
				land.append(n)
	var tries := samples * 6
	while tries > 0 and _spots.size() < samples:
		tries -= 1
		var p := Vector2(randf_range(area.position.x, area.end.x),
				randf_range(area.position.y, area.end.y))
		if _is_water(p, water) and not _is_water(p, land):
			_spots.append(p)


func _is_water(p: Vector2, layers: Array[TileMapLayer]) -> bool:
	for l in layers:
		if l.get_cell_source_id(l.local_to_map(l.to_local(p))) != -1:
			return true
	return false


func _process(delta: float) -> void:
	if _spots.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(interval_min, interval_max)
	for l in _leaps:
		if not l.visible:
			l.leap(_spots[randi() % _spots.size()], randi() % dolphin_one_in == 0)
			break


func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out += _all(c)
	return out
